# The majority of the Supplejack API code is Crown copyright (C) 2014, New Zealand Government, 
# and is licensed under the GNU General Public License, version 3.
# One component is a third party component. See https://github.com/DigitalNZ/supplejack_api for details. 
# 
# Supplejack was created by DigitalNZ at the National Library of NZ and 
# the Department of Internal Affairs. http://digitalnz.org/supplejack

module SupplejackApi
  class RequestLog
    include Mongoid::Document
    include Mongoid::Timestamps
  
    store_in collection: 'request_log'
    
    field :request_type,       type: string
    field :results,         type: string
  
    index created_at: 1
  end
end
