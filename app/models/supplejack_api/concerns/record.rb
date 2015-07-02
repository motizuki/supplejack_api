module SupplejackApi::Concerns::Record
  extend ActiveSupport::Concern

  included do
    attr_accessor :next_record, :previous_record, :next_page, :previous_page
    attr_accessor :should_index_flag

    # Associations
    embeds_many :fragments, cascade_callbacks: true, class_name: 'SupplejackApi::ApiRecord::RecordFragment'
    embeds_one :merged_fragment, class_name: 'SupplejackApi::ApiRecord::RecordFragment'
    has_and_belongs_to_many :concepts, class_name: 'SupplejackApi::Concept'

    # From storable
    store_in collection: 'records'
    index({ concept_ids: 1})
    index({ record_id: 1 }, { unique: true })
    auto_increment :record_id, session: 'strong'

    # Callbacks
    before_save :merge_fragments

    # Scopes
    scope :active, -> { where(status: 'active') }
    scope :deleted, -> { where(status: 'deleted') }
    scope :suppressed, -> { where(status: 'suppressed') }
    scope :solr_rejected, -> { where(status: 'solr_rejected') }

    build_model_fields

    def self.find_multiple(ids)
      return [] unless ids.try(:any?)
      string_ids = ids.find_all {|id| id.to_s.length > 10 }
      integer_ids = ids.find_all {|id| id.to_s.length <= 10 }

      records =[]
      records += self.active.find(string_ids) if string_ids.present?
      records += self.active.where(:record_id.in => integer_ids)
      records = records.sort_by {|r| ids.find_index(r.record_id) || 100 }
    end

    def find_next_and_previous_records(scope, options={})
      if options.try(:any?)
        search = ::SupplejackApi::RecordSearch.new(options)
        search.scope = scope

        return nil unless search.valid?

        # Find the index in the array for the current record
        record_index = search.hits.find_index {|i| i.primary_key == self.id.to_s}
        total_pages = (search.total.to_f / search.per_page).ceil

        self.next_page = search.page
        self.previous_page = search.page

        if record_index
          if record_index == 0
            unless search.page == 1
              previous_page_search = ::SupplejackApi::RecordSearch.new(options.merge(:page => search.page - 1))
              previous_primary_key = previous_page_search.hits[-1].try(:primary_key)
              self.previous_page = search.page - 1
            end
          else
            previous_primary_key = search.hits[record_index-1].try(:primary_key)
          end

          if previous_primary_key.present?
            self.previous_record = SupplejackApi::Record.find(previous_primary_key).try(:record_id) rescue nil
          end

          if record_index == search.hits.size-1
            unless search.page >= total_pages
              next_page_search = ::SupplejackApi::RecordSearch.new(options.merge(:page => search.page + 1))
              next_primary_key = next_page_search.hits[0].try(:primary_key)
              self.next_page = search.page + 1
            end
          else
            next_primary_key = search.hits[record_index+1].try(:primary_key)
          end

          if next_primary_key.present?
            self.next_record = ::SupplejackApi::Record.find(next_primary_key).try(:record_id) rescue nil
          end
        end
      end
    end

    def active?
      self.status == 'active'
    end

    def should_index?
      return should_index_flag if !should_index_flag.nil?
      active?
    end

    def fragment_class
      SupplejackApi::ApiRecord::RecordFragment
    end
  end

end