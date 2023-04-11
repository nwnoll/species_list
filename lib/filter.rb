# frozen_string_literal: true

class Filter
    def self.select_names(occurence_of_taxon:)

        previous_name = nil
        selected_names = []
        
        occurence_of_taxon.keys.sort.each do |key|

            previous_name               = key and next if previous_name.nil?
            current_parsed_name         = occurence_of_taxon[key].first
            previous_parsed_name        = occurence_of_taxon[previous_name].first
        
            previous_parsed_canonical   = previous_parsed_name[:canonical][:full]
            current_parsed_canonical    = current_parsed_name[:canonical][:full]

            unless previous_parsed_canonical == current_parsed_canonical
                selected_names.push(key)
                previous_name = key
                next
            end


            # different name but same species binomial
            selected_names.pop
    
            previous_parsed_authorship = previous_parsed_name[:authorship]
            current_parsed_authorship = current_parsed_name[:authorship]
    
            # one has no author information, therefore jsut use the one that has? or both?
            if previous_parsed_authorship.nil?
                selected_names.push(key)
                occurence_of_taxon[key].push(occurence_of_taxon[previous_name].drop(1))
                previous_name = key
                next
            elsif current_parsed_authorship.nil?
                selected_names.push(previous_name)
                occurence_of_taxon[previous_name].push(occurence_of_taxon[key].drop(1))
                previous_name = key
                next
            end
    
    
            # if both do have authorship but one does not have a year annd bot have the same author then discard the one with no year
            if previous_parsed_authorship[:year].nil? || current_parsed_authorship[:year].nil?
                if previous_parsed_authorship[:authors].sort == current_parsed_authorship[:authors].sort
                    if previous_parsed_authorship[:year].nil?
                        selected_names.push(key)
                        occurence_of_taxon[key].push(occurence_of_taxon[previous_name].drop(1))
                        previous_name = key
                        next
                    elsif current_parsed_authorship[:year].nil?
                        selected_names.push(previous_name)
                        occurence_of_taxon[previous_name].push(occurence_of_taxon[key].drop(1))
                        previous_name = key
                        next
                    end
                else
                    _add_taxon_occurences(previous_name: previous_name, key: key, selected_names: selected_names, occurence_of_taxon: occurence_of_taxon)
                    previous_name = key
                    next
                end
            end
    
            previous_parsed_normalized  = previous_parsed_authorship[:normalized]
            current_parsed_normalized   = current_parsed_authorship[:normalized]
    
            # is species considere to be in a different genus?
            # if the canonical anme is the same but one uses parentheses and therefore assumes that
            # the species was moved to another genus, I should retain both?
            if /[()]/.match?(previous_parsed_normalized) ^ /[()]/.match?(current_parsed_normalized)
                _add_taxon_occurences(previous_name: previous_name, key: key, selected_names: selected_names, occurence_of_taxon: occurence_of_taxon)
                previous_name = key
                next
            end
    
    
            if previous_parsed_authorship && current_parsed_authorship
                previous_parsed_year   = previous_parsed_authorship[:year]
                current_parsed_year = current_parsed_authorship[:year]
                # same binomial but different year, always label as different
                if previous_parsed_year != current_parsed_year
                    _add_taxon_occurences(previous_name: previous_name, key: key, selected_names: selected_names, occurence_of_taxon: occurence_of_taxon)
                    previous_name = key
                    next
                end
            end
    
            previous_parsed_normalized_normalized   = Helper.normalize(previous_parsed_name[:normalized])
            current_parsed_normalized_normalized    = Helper.normalize(current_parsed_name[:normalized])
            
            # same binomen, and same normalized name, label as equal, should take which name?
            if previous_parsed_normalized_normalized == current_parsed_normalized_normalized
                if Helper::UMLAUTE_REGEXP === previous_parsed_name[:normalized]
                    selected_names.push(previous_name)
                    occurence_of_taxon[previous_name].push(occurence_of_taxon[key].drop(1))
                    previous_name = key
                    next
                elsif Helper::UMLAUTE_REGEXP === current_parsed_name[:normalized]
                    selected_names.push(key)
                    occurence_of_taxon[key].push(occurence_of_taxon[previous_name].drop(1))
                    previous_name = key
                    next
                else
                    ## this happens if entry has spaces in author names like DeGeer
                    ## and the other doesnt e.g. DeGeer
                    if previous_name.count("\s") > key.count("\s")
                        selected_names.push(previous_name)
                        occurence_of_taxon[previous_name].push(occurence_of_taxon[key].drop(1))
                        previous_name = key
                        next
                    else
                        selected_names.push(key)
                        occurence_of_taxon[key].push(occurence_of_taxon[previous_name].drop(1))
                        previous_name = key
                        next
                    end
                end
            end
    
            # uses the normalized output from the parser, normalizes it again becaus eof german Umlaute etc
            # and then checks if it the same when ignoring case
            # it also casefolds character like ß to SS, therefore Claßen and Classen give true here
            if previous_parsed_normalized_normalized.casecmp?(current_parsed_normalized_normalized)
                # take the one with a smaller size therefore extra characters like ß will be preserved
                if previous_parsed_normalized_normalized.size < current_parsed_normalized_normalized.size
                    selected_names.push(previous_name)
                    occurence_of_taxon[previous_name].push(occurence_of_taxon[key].drop(1))
                    previous_name = key
                    next
                elsif previous_parsed_normalized_normalized.size > current_parsed_normalized_normalized.size
                    selected_names.push(key)
                    occurence_of_taxon[key].push(occurence_of_taxon[previous_name].drop(1))
                    previous_name = key
                    next
                else
                    _add_taxon_occurences(previous_name: previous_name, key: key, selected_names: selected_names, occurence_of_taxon: occurence_of_taxon)
                    previous_name = key
                    next
                end
            end
    
    
    
            if previous_parsed_authorship && current_parsed_authorship
            
                previous_parsed_authors = previous_parsed_authorship[:authors]
                current_parsed_authors  = current_parsed_authorship[:authors]
    
                if Helper.same_authorship?(previous_parsed_authors, current_parsed_authors)
                    if previous_parsed_normalized.gsub('.', '').size > current_parsed_normalized.gsub('.', '').size
                        selected_names.push(previous_name)
                        occurence_of_taxon[previous_name].push(occurence_of_taxon[key].drop(1))
                        previous_name = key
                        next
                    elsif current_parsed_normalized.gsub('.', '').size > previous_parsed_normalized.gsub('.', '').size
                        selected_names.push(key)
                        occurence_of_taxon[key].push(occurence_of_taxon[previous_name].drop(1))
                        previous_name = key
                        next
                    else
                        _add_taxon_occurences(previous_name: previous_name, key: key, selected_names: selected_names, occurence_of_taxon: occurence_of_taxon)
                        previous_name = key
                        next
                    end
                end
            end
    
            _add_taxon_occurences(previous_name: previous_name, key: key, selected_names: selected_names, occurence_of_taxon: occurence_of_taxon)
            previous_name = key
        end

        filtered_name_entries_of = Hash.new

        selected_names.sort.each do |name|
            filtered_name_entries_of[name] = occurence_of_taxon[name].flatten
        end

        return filtered_name_entries_of
    end

    def self._add_taxon_occurences(previous_name:, key:, selected_names:, occurence_of_taxon:)
        current_entries_to_push = occurence_of_taxon[key].drop(1)
        previous_entries_to_push = occurence_of_taxon[previous_name].drop(1)
    
        selected_names.push(previous_name)
        occurence_of_taxon[previous_name].push(current_entries_to_push)
    
        selected_names.push(key)
        occurence_of_taxon[key].push(previous_entries_to_push)
    end
end