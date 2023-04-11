# frozen_string_literal: true

class TaxonOccurenceParser
    BREAK_BY = 20_000

    def self.parse_gbif_species_list(file_name:, into:)
        
        gbif_file = File.open(file_name)
        gbif_csv   = CSV.new(gbif_file, headers: true, col_sep: "\t", liberal_parsing: true)

        gbif_csv.each do |row|
            # break if gbif_csv.lineno == BREAK_BY

            next unless row["taxonRank"] =~ /SPECIES/

            ident_name = row["scientificName"]

            parsed_name = Biodiversity::Parser.parse(ident_name)
            next unless parsed_name[:parsed]

            lineage = [row["kingdom"], row["phylum"], row["class"], row["family"], row["genus"]]

            occurence_obj = TaxonOccurence.new(
                ident_name: ident_name,
                ident_gbif_taxon_id: row["taxonKey"],
                accepted_name: row["acceptedScientificName"],
                accepted_gbif_taxon_id: row["acceptedTaxonKey"],
                lineage: lineage,
                gbol_catalogue_id: nil,
                country: 'Germany', # I used the filter for german occurences, TODO: here maybe parameter for different datasets
                other_catalogue_id: nil,
                barcode_available: nil,
                source: 'GBIF',
            )

            if  into.key?(ident_name)
                into[ident_name].push(occurence_obj)
            else
                into[ident_name].push(parsed_name)
                into[ident_name].push(occurence_obj)
            end
        end
    end


    def self.parse_gbol_species_list(file_name:, into:)
        gbol_file = File.open(file_name, 'r')
        gbol_csv = CSV.new(gbol_file, headers: true, col_sep: "\t", liberal_parsing: true)
        
        gbol_csv.each do |row|
            # break if gbol_csv.lineno == BREAK_BY

            ident_name = row[0]
            gbol_catalogue_id = row[2]
            lineage = [row[3]]
            country = row[7]
            other_catalogue_id = row[17]
            barcode_available_sign = row[21]
            barcode_available = barcode_available_sign == "✔" ? true : false
        
            parsed_name = Biodiversity::Parser.parse(ident_name)
            next unless parsed_name[:parsed]
            

            canonical_name = parsed_name[:canonical][:full]
        
            occurence_obj = TaxonOccurence.new(
                ident_name: ident_name,
                ident_gbif_taxon_id: nil,
                accepted_name: nil,
                accepted_gbif_taxon_id: nil,
                lineage: lineage,
                gbol_catalogue_id: gbol_catalogue_id,
                country: country,
                other_catalogue_id: other_catalogue_id,
                barcode_available: barcode_available,
                source: 'GBOL',
            )
        
            # if  into.key?(ident_name)
            #     into[ident_name].push(occurence_obj)
            # else
            #     into[ident_name].push(parsed_name)
            #     into[ident_name].push(occurence_obj)
            # end

            if  into.key?(canonical_name)
                into[canonical_name].push(occurence_obj)
            else
                into[canonical_name].push(parsed_name)
                into[canonical_name].push(occurence_obj)
            end
        end        
    end


    def self.parse_gbol_missing_species_list(file_name:, into:)
        gbol_missing_file = File.open(file_name, 'r')
        gbol_missing_csv = CSV.new(gbol_missing_file, headers: true, col_sep: ",", liberal_parsing: true)
        
        
        # "Familie","Art","BOLD-Suche"


        gbol_missing_csv.each do |row|
            ident_name = row["Art"]
            lineage = [row["Familie"]]
            country = 'Germany'

            parsed_name = Biodiversity::Parser.parse(ident_name)
            next unless parsed_name[:parsed]

            occurence_obj = TaxonOccurence.new(
                ident_name: ident_name,
                ident_gbif_taxon_id: nil,
                accepted_name: nil,
                accepted_gbif_taxon_id: nil,
                lineage: lineage,
                gbol_catalogue_id: nil,
                country: country,
                other_catalogue_id: nil,
                barcode_available: nil,
                source: 'MISSING_GBOL',     
            )

            if  into.key?(ident_name)
                into[ident_name].push(occurence_obj)
            else
                into[ident_name].push(parsed_name)
                into[ident_name].push(occurence_obj)
            end
        end
    end
end