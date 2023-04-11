# frozen_string_literal: true

class Barcodes
    ## https://stackoverflow.com/questions/37979457/fastest-way-to-search-string-in-large-text-file

    def self.add_bold_ids(from_hash:, to_hash:)
        from_hash.keys.sort.each do |key|
            index_for_filtered = to_hash.keys.sort.bsearch_index { |e| key <=> to_hash[e].first[:canonical][:full] }
            next unless index_for_filtered
            
            key_for_filtered = to_hash.keys.sort[index_for_filtered]
            
            bold_ids = BoldIds.new
            from_hash[key][:data].each do |specimen|
                bold_ids.add(specimen[:identifier])
            end
        
            to_hash[key_for_filtered].push(bold_ids)
        
            # byebug
            ## IN CURRENT IMPLEMNETATION NOT ANYMORE TRUE
            ## THEREFORE EVERYTHING IS COMMENTED
            ## since we make a binary search and we might have the same canonical name multiple times
            ## with different authorship, we also want to check if the entry one before and after the one was taken
            ## has the same canonical name and then we want to add the bold_ids...
            ## Problem here is that if the author really differ, it is not a good way to handle it
            ## the thing is that msotly the authorship is just different because of misspelling.. wrong year etc.
            ## then it would be bad if the sequences are just in one of these variants
            
            # if index_for_filtered > 0
            #     second_index_for_filtered = index_for_filtered - 1
            #     second_key_for_filtered = to_hash.keys.sort[second_index_for_filtered]
                
            #     parsed_first_name = to_hash[key_for_filtered].first
            #     parsed_second_name = to_hash[second_key_for_filtered].first
        
            #     if parsed_first_name[:canonical][:full] == parsed_second_name[:canonical][:full]
            #         to_hash[second_key_for_filtered].push(bold_ids)
            #         next
            #     end
        
            #     next if index_for_filtered == (to_hash.keys.size - 1)
        
            #     third_index_for_filtered = index_for_filtered + 1
            #     third_key_for_filtered = to_hash.keys.sort[third_index_for_filtered]
                
            #     parsed_third_name = to_hash[third_key_for_filtered].first
        
            #     if parsed_first_name[:canonical][:full] == parsed_third_name[:canonical][:full]
            #         to_hash[third_key_for_filtered].push(bold_ids)
            #         next
            #     end
            # else
            #     next if index_for_filtered == (to_hash.keys.size - 1)
        
            #     third_index_for_filtered = index_for_filtered + 1
            #     third_key_for_filtered = to_hash.keys.sort[third_index_for_filtered]
                
        
            #     # byebug if to_hash[third_key_for_filtered].nil?
            #     parsed_third_name = to_hash[third_key_for_filtered].first
        
            #     if parsed_first_name[:canonical][:full] == parsed_third_name[:canonical][:full]
            #         to_hash[third_key_for_filtered].push(bold_ids)
            #         next
            #     end
            # end
        end
    end
end

class BoldIds
    attr_accessor :ids
    
    def initialize
        @ids = []
    end

    def add(id)
        ids.push(id)
    end
end