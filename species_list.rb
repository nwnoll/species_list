# frozen_string_literal: true

require './requirements'

params = {}
OptionParser.new do |opts|
    opts.set_summary_width 80

    opts.on('-g GBIF_SPECIES_LIST', '--gbif_species_list')
    opts.on('-G GBOL_SPECIES_LIST', '--gbol_species_list')
    opts.on('-m GBOL_MISSING_SPECIES_LIST', '--gbol_missing_species_list')
    opts.on('-o GBOL_SPECIMEN_DATA', '--gbol_specimen_data')
    opts.on('-b BOLD_SPECIMEN_DATA', '--bold_specimen_data')
    opts.on('-k GENBANK_SPECIMEN_DATA', '--genbank_specimen_data')
    opts.on('-r MIDORI_SPECIMEN_DATA', '--midori_specimen_data')
    opts.on('-t TAXON', '--taxon')
    opts.on('-c COUNTRY', '--country')
end.parse!(into: params)


TaxonOccurence = Struct.new(
    :ident_name,
    :ident_gbif_taxon_id,
    :accepted_name,
    :accepted_gbif_taxon_id,
    :lineage,
    :gbol_catalogue_id,
    :country,
    :other_catalogue_id,
    :barcode_available,
    :source,

    keyword_init: true
)

query_taxon_object = nil
if params[:taxon]
    taxon_name = params[:taxon]
    query_taxon_object = GbifTaxonomy.find_by(canonical_name: taxon_name)
    abort "Cant find #{taxon_name}, please use only species, genus, family, order, phylum or kingdom ranks" unless query_taxon_object
else
    query_taxon_object = GbifTaxonomy.find_by(canonical_name: 'Insecta')
end


occurence_of_taxon = Hash.new { |h, k| h[k] = [] }


bold_specimens_of = nil
if params[:bold_specimen_data]
    bold_download_file_name =  params[:bold_specimen_data]
    abort "file #{bold_download_file_name} does not exist, pleas provide valid GBOL Species List" unless File.file?(bold_download_file_name)
    
    bold_specimens_of =  BoldCombinedParser.new(file_name:bold_download_file_name, query_taxon_object: query_taxon_object).run
    # Barcodes.add_bold_ids(from_hash: bold_specimens_of, to_hash: occurence_of_taxon)
    puts 'got bold_specimen_data'
end


midori_specimens_of = nil
if params[:midori_specimen_data]
    midori_fasta_file_name = params[:midori_specimen_data]
    abort "file #{midori_fasta_file_name} does not exist, pleas provide valid GBIF Species List" unless File.file?(midori_fasta_file_name)

    midori_specimens_of = MidoriFastaParser.new(file_name: midori_fasta_file_name, query_taxon_object: query_taxon_object).run
    puts 'got midori'
end


if params[:gbif_species_list]
    gbif_species_file_name = params[:gbif_species_list]
    abort "file #{gbif_species_file_name} does not exist, pleas provide valid GBIF Species List" unless File.file?(gbif_species_file_name)
    
    TaxonOccurenceParser.parse_gbif_species_list(file_name: gbif_species_file_name, into: occurence_of_taxon)
    puts 'got gbif_species_list'

end


if params[:gbol_species_list]
    gbol_species_list_name = params[:gbol_species_list]
    abort "file #{gbol_species_list_name} does not exist, pleas provide valid GBOL Species List" unless File.file?(gbol_species_list_name)
    
    TaxonOccurenceParser.parse_gbol_species_list(file_name: gbol_species_list_name, into: occurence_of_taxon)
    puts 'got gbol_species_list'
end


if params[:gbol_missing_species_list]
    gbol_missing_species_list_name = params[:gbol_missing_species_list]
    abort "file #{gbol_missing_species_list_name} does not exist, pleas provide valid GBOL Missing Species List" unless File.file?(gbol_missing_species_list_name)
    
    TaxonOccurenceParser.parse_gbol_missing_species_list(file_name: gbol_missing_species_list_name, into: occurence_of_taxon)
    puts 'got gbol_missing_species_list'
end


occurence_of_taxon = occurence_of_taxon.sort.to_h
# filtered_name_entries_of = Filter.select_names(occurence_of_taxon: occurence_of_taxon)


gbol_specimens_of = nil
if params[:gbol_specimen_data]
    gbol_download_file_name = params[:gbol_specimen_data]
    abort "file #{gbol_download_file_name} does not exist, pleas provide valid GBOL Species List" unless File.file?(gbol_download_file_name)

    gbol_specimens_of = GbolCombinedParser.new(file_name: gbol_download_file_name, query_taxon_object: query_taxon_object).run
    puts 'got gbol_specimen_data'
end


# occurence_of_taxon.keys.sort.each do |key|
#     canonical_name_normalized = Helper.normalize(key)
#     nomial = Nomial.new(parsed_name: occurence_of_taxon[key].first, query_taxon_name: 'Insecta', are_synonyms_allowed: true)
#     obj = nomial.gbif_taxonomy_backbone(first_specimen_info: occurence_of_taxon[key].last)

# end


def create_specimen_output(occurence_of_taxon:, gbol_specimens_of:)
    outputs = []
    file = File.open('specimen_data.txt', 'w')
    file.puts "taxon_id\tspecies_name\tdate\tspecimen_id\tspecimen_source\tlink"
    count = 0
    occurence_of_taxon.each do |key, value|
        count += 1

        # bold_ids_from_bold_dl = value.last.is_a?(BoldIds) ? value.pop : nil

        gbol_ids = []
        bold_ids = []
        only_gbol_barcodes = []

        value.drop(1).each do |spec|
            gbol_ids.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id
            bold_ids.push(spec.other_catalogue_id) if spec.other_catalogue_id
            only_gbol_barcodes.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id && spec.barcode_available && !spec.other_catalogue_id
        end

        if bold_specimens_of.key?(key)
            bold_specimens_of[key][:data].each do |specimen_data|
                bold_ids.push(specimen_data[:identifier])
            end
        end

        # bold_ids.push(bold_ids_from_bold_dl.ids.flatten) if bold_ids_from_bold_dl

        link_of = Hash.new
        if gbol_specimens_of.key?(key)
            gbol_specimens_of[key][:data].each do |specimen_data|
                link_of[specimen_data[:identifier]] = specimen_data[:link]
                gbol_ids.push(specimen_data[:identifier])
                bold_ids.push(specimen_data[:other_identifier]) if specimen_data[:other_identifier]
            end
        end

        ## TODO:
        ## change bold_ids to type Set
        bold_ids = bold_ids.compact.flatten.uniq
        gbol_ids = gbol_ids.compact.flatten.uniq
        
        gbol_ids.each do |gbol_id|
            file.print count, "\t"
            file.print key, "\t"
            file.print "28.02.2021", "\t"
            file.print gbol_id, "\t"
            file.print 'gbol', "\t"
            file.print link_of[gbol_id], "\n"
        end

        bold_ids.each do |bold_id|
            file.print count, "\t"
            file.print key, "\t"
            file.print "28.02.2021", "\t"
            file.print bold_id, "\t"
            file.print 'bold', "\t"
            file.print "https://www.boldsystems.org/index.php/Public_RecordView?processid=#{bold_id}", "\n"
        end
    end
end


def create_outputs2(species_list_out:, specimen_out:, occurence_of_taxon:, gbol_specimens_of:, midori_specimens_of:, bold_specimens_of:)
    # outputs = []
    # specimen_outputs = []

    species_list_out.puts "id\tdate\tphylum\tclass\torder\tfamily\tgenus\tspecies\tauthorship\tyear\tcountry\tlineage_source\tauthorship_source\tnum_barcodes"
    specimen_out.puts "id\tdate\tspecies\tspecimen_id\tspecimen_source\tlink"
    
    count = 0
    occurence_of_taxon.each do |key, value|
        puts count
        count += 1
        name_to_use = value.first

        # bold_ids_from_bold_dl = value.last.is_a?(BoldIds) ? value.pop : nil
    
        full_normalized_name = name_to_use[:normalized]
        canonical_name = name_to_use[:canonical][:full]
        canonical_name_normalized = Helper.normalize(canonical_name)
    
        ## Homonym check?
        ##
    
        phylum = nil
        classis = nil
        ordo = nil
        familia = nil
        genus = nil
        species = nil
        author = nil
        year = nil
        source = nil
        # localities = []
        country = 'Germany'
        links = []
        genbank_ids = []
        gbol_ids = []
        bold_ids = []
    
        nomial = Nomial.new(parsed_name: name_to_use, query_taxon_name: 'Insecta', are_synonyms_allowed: true)
        gbif_obj = nomial.gbif_taxonomy_backbone(first_specimen_info: occurence_of_taxon[key].last)
        ncbi_obj = nomial.ncbi_taxonomy(first_specimen_info: occurence_of_taxon[key].last)

        if gbif_obj.nil? && ncbi_obj.nil?
            next
        elsif gbif_obj && ncbi_obj
            next unless gbif_obj.taxon_rank =~ /species/ && ncbi_obj.taxon_rank =~ /species/
        elsif gbif_obj.nil? && ncbi_obj
            next unless ncbi_obj.taxon_rank =~ /species/
        elsif ncbi_obj.nil? && gbif_obj
            next unless gbif_obj.taxon_rank =~ /species/
        end


        ## GBOL WITH SPECIMENS
        ## gbif lineage + gbol author
        ## ncbi lineage + gbol author
        ## gbif lineage + gbif author
        ## ncbi lineage + ncbi author

        ## GBOL WITHOUT SPECIMENS
        ## gbif lineage + gbif author
        ## ncbi lineage + ncbi author

        num_barcodes = 0
        only_gbol_barcodes = []
        value.drop(1).each do |spec|
            gbol_ids.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id
            bold_ids.push(spec.other_catalogue_id) if spec.other_catalogue_id
            only_gbol_barcodes.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id && spec.barcode_available && !spec.other_catalogue_id
        end
    
        num_barcodes += only_gbol_barcodes.size


        specimen_objects = []
        midori_genbank_ids = []
        if midori_specimens_of.key?(key)
            midori_specimens_of[key][:data].each do |specimen_data|
                obj = OpenStruct.new(
                    id: count,
                    species: key,
                    date: "02.03.2021",
                    specimen_id: specimen_data[:identifier],
                    specimen_source: 'midori gb241',
                    link: specimen_data[:link]
                )
                midori_genbank_ids.push(specimen_data[:identifier])
                specimen_objects.push(obj)
            end
            num_barcodes += midori_specimens_of[key][:data].size
        end

        if bold_specimens_of.key?(key)
            bold_specimens_of[key][:data].each do |specimen_data|
                unless specimen_data[:other_identifier] && midori_genbank_ids.include?(specimen_data[:other_identifier])
                    bold_ids.push(specimen_data[:identifier]) 
                end
            end
        end
    
        # TODO: this does not implement search for authors... or stem or etc...
        # bold_ids.push(bold_ids_from_bold_dl.ids.flatten) if bold_ids_from_bold_dl

        link_of = Hash.new
        gbol_ids_from_dataset_release = []
        if gbol_specimens_of.key?(key)
            gbol_specimens_of[key][:data].each do |specimen_data|
                link_of[specimen_data[:identifier]] = specimen_data[:link]
                gbol_ids.push(specimen_data[:identifier])
                gbol_ids_from_dataset_release.push(specimen_data[:identifier])
                bold_ids.push(specimen_data[:other_identifier]) if specimen_data[:other_identifier]
            end
        end

        new_gbol_ids = gbol_ids_from_dataset_release - only_gbol_barcodes
        num_barcodes += new_gbol_ids.size




        ## TODO:
        ## change bold_ids to type Set
        bold_ids = bold_ids.compact.flatten.uniq
        gbol_ids = gbol_ids.compact.flatten.uniq

        num_barcodes += bold_ids.size

        gbol_ids.each do |gbol_id|
            obj = OpenStruct.new(
                id: count,
                species: key,
                date: "02.03.2021",
                specimen_id: gbol_id,
                specimen_source: 'gbol',
                link: link_of[gbol_id]
            )

            specimen_objects.push(obj)
        end

        bold_ids.each do |bold_id|
            obj = OpenStruct.new(
                id: count,
                species: key,
                date: "02.03.2021",
                specimen_id: bold_id,
                specimen_source: 'bold',
                link: "https://www.boldsystems.org/index.php/Public_RecordView?processid=#{bold_id}"
            )

            specimen_objects.push(obj)
        end
        
        output_objects = []
        if value.drop(1).first.source == 'MISSING_GBOL'
            obj1 = create_output_obj(id: count, species_name: key, source_obj: gbif_obj, name_to_use: nil, used_species_list: 'MISSING_GBOL', from_source: :gbif, num_barcodes: num_barcodes)
            obj2 = create_output_obj(id: count, species_name: key, source_obj: ncbi_obj, name_to_use: nil, used_species_list: 'MISSING_GBOL', from_source: :ncbi, num_barcodes: num_barcodes)
            
            output_objects.push(obj1) unless obj1.nil?
            output_objects.push(obj2) unless obj2.nil?
        else
            obj1 = create_output_obj(id: count, species_name: key, source_obj: gbif_obj, name_to_use: name_to_use, used_species_list: nil, from_source: :gbif, num_barcodes: num_barcodes)
            obj2 = create_output_obj(id: count, species_name: key, source_obj: gbif_obj, name_to_use: nil, used_species_list: nil, from_source: :gbif, num_barcodes: num_barcodes)
            obj3 = create_output_obj(id: count, species_name: key, source_obj: ncbi_obj, name_to_use: name_to_use, used_species_list: nil, from_source: :ncbi, num_barcodes: num_barcodes)
            obj4 = create_output_obj(id: count, species_name: key, source_obj: ncbi_obj, name_to_use: nil, used_species_list: nil, from_source: :ncbi, num_barcodes: num_barcodes)
        
            output_objects.push(obj1) unless obj1.nil?
            output_objects.push(obj2) unless obj2.nil?
            output_objects.push(obj3) unless obj3.nil?
            output_objects.push(obj4) unless obj4.nil?
        end

        output_objects.flatten!
        output_objects.each do |obj|
            species_list_out.print "#{obj.id}\t"
            species_list_out.print "#{obj.date}\t"
            species_list_out.print "#{obj.phylum}\t"
            species_list_out.print "#{obj.classis}\t"
            species_list_out.print "#{obj.ordo}\t"
            species_list_out.print "#{obj.familia}\t"
            species_list_out.print "#{obj.genus}\t"
            species_list_out.print "#{obj.species}\t"
            species_list_out.print "#{obj.authors}\t"
            species_list_out.print "#{obj.year}\t"
            species_list_out.print "#{obj.country}\t"
            species_list_out.print "#{obj.lineage_source}\t"
            species_list_out.print "#{obj.author_source}\t"
            species_list_out.print "#{obj.num_barcodes}\n"
        end

        specimen_objects.flatten!
        specimen_objects.each do |obj|
            specimen_out.print obj.id, "\t"
            specimen_out.print obj.date, "\t"
            specimen_out.print obj.species, "\t"
            specimen_out.print obj.specimen_id, "\t"
            specimen_out.print obj.specimen_source, "\t"
            specimen_out.print obj.link, "\n"
        end


        # outputs.push(output_objects).flatten!
    end
    
    # return [outputs, specimen_outputs]
end

def create_output_obj(id:, species_name:, source_obj:, name_to_use:, used_species_list:, from_source:, num_barcodes: nil)

    return nil if source_obj.nil?
    ## GBOL WITH SPECIMENS
    ## gbif lineage + gbol author
    ## ncbi lineage + gbol author
    ## gbif lineage + gbif author
    ## ncbi lineage + ncbi author

    ## GBOL WITHOUT SPECIMENS
    ## gbif lineage + gbif author
    ## ncbi lineage + ncbi author

    phylum = source_obj.phylum
    classis = source_obj.classis
    ordo = source_obj.ordo
    familia = source_obj.familia
    genus = source_obj.genus
    # species =  obj.canonical_name
    species = species_name
    lineage_source = from_source.to_s
    # localities = []
    country = 'Germany'
    links = []
    genbank_ids = []
    gbol_ids = []
    bold_ids = []
    # authors_joined = name_to_use[:authorship][:authors].join(' & ') if name_to_use[:authorship]

    ## TODO:
    ## NEXT
    # Problem is that it states hat source is from gbol 
    # should implement a lineage_source and a authorsource?
    # 12.02.2021	Arthropoda	Insecta	Coleoptera	Melyandrida	Abdera	Abdera flexuosa	(Payk. 1799)	1799	Germany	gbol
    # 12.02.2021	Arthropoda	Insecta	Coleoptera	Melandryidae	Abdera	Abdera flexuosa	(Payk. 1799)	1799	Germany	gbol

    parsed_name = Biodiversity::Parser.parse(source_obj.scientific_name)
    return nil unless parsed_name[:parsed]

    if used_species_list == 'MISSING_GBOL'
        # byebug if from_source == :ncbi

        authors_joined = parsed_name[:authorship][:normalized] if parsed_name[:authorship]
        authors_year = parsed_name[:authorship][:year] if parsed_name[:authorship]
        
        author_source = from_source.to_s

    elsif name_to_use
        authors_joined = name_to_use[:authorship][:normalized] if name_to_use[:authorship]
        authors_year = name_to_use[:authorship][:year] if name_to_use[:authorship]
        
        author_source = 'gbol'
    elsif name_to_use.nil?

        authors_joined = parsed_name[:authorship][:normalized] if parsed_name[:authorship]
        authors_year = parsed_name[:authorship][:year] if parsed_name[:authorship]
        
        author_source = from_source.to_s
    end


    output = OpenStruct.new(
        id: id,
        date:'02.03.2021',
        phylum: phylum,
        classis: classis,
        ordo: ordo,
        familia: familia,
        genus: genus,
        species: species_name,
        authors: authors_joined,
        year: authors_year,
        # localities: localities.compact.uniq.join(','),
        country: country,
        lineage_source: lineage_source,
        author_source: author_source,
        # links: 'TODO',
        num_barcodes: num_barcodes
        # genbank_ids: 'TODO',
        # gbol_ids: gbol_ids.compact.flatten.uniq.join(','),
        # bold_ids: bold_ids.compact.flatten.uniq.join(',')
    )
end

def create_outputs(occurence_of_taxon:, from_source:)
    outputs = []
    not_found   = File.open("__not_found_in_#{from_source.to_s}", 'w')
    
    occurence_of_taxon.each do |key, value|
        name_to_use = value.first
        # byebug unless name_to_use.class == Hash

        # bold_ids_from_bold_dl = value.last.is_a?(BoldIds) ? value.pop : nil
    
        full_normalized_name = name_to_use[:normalized]
        canonical_name = name_to_use[:canonical][:full]
        canonical_name_normalized = Helper.normalize(canonical_name)
    
        # puts full_normalized_name
    
        ## Homonym check?
        ##
    
        phylum = nil
        classis = nil
        ordo = nil
        familia = nil
        genus = nil
        species = nil
        author = nil
        year = nil
        source = nil
        # localities = []
        country = 'Germany'
        links = []
        genbank_ids = []
        gbol_ids = []
        bold_ids = []
    
        nomial = Nomial.new(parsed_name: name_to_use, query_taxon_name: 'Insecta', are_synonyms_allowed: true)
        if from_source ==  :gbif
            obj = nomial.gbif_taxonomy_backbone(first_specimen_info: occurence_of_taxon[key].last)
        elsif from_source == :ncbi
            obj = nomial.ncbi_taxonomy(first_specimen_info: occurence_of_taxon[key].last)
        else
            obj = nomial.gbif_taxonomy_backbone(first_specimen_info: occurence_of_taxon[key].last)
        end


        not_found.puts key if obj.nil?
    
        next if obj.nil?
        next unless obj.taxon_rank =~ /species/
    
        phylum = obj.phylum
        classis = obj.classis
        ordo = obj.ordo
        familia = obj.familia
        genus = obj.genus
        species =  obj.canonical_name
        species =  key
        lineage_source = from_source.to_s
        # authors_joined = name_to_use[:authorship][:authors].join(' & ') if name_to_use[:authorship]
    
        ## TODO:
        ## NEXT
        # Problem is that it states hat source is from gbol 
        # should implement a lineage_source and a authorsource?
        # 12.02.2021	Arthropoda	Insecta	Coleoptera	Melyandrida	Abdera	Abdera flexuosa	(Payk. 1799)	1799	Germany	gbol
        # 12.02.2021	Arthropoda	Insecta	Coleoptera	Melandryidae	Abdera	Abdera flexuosa	(Payk. 1799)	1799	Germany	gbol


        if value.drop(1).first.source == 'MISSING_GBOL'
            # byebug if from_source == :ncbi
            parsed_name = Biodiversity::Parser.parse(obj.scientific_name)
            next unless parsed_name[:parsed]

            authors_joined = parsed_name[:authorship][:normalized] if parsed_name[:authorship]
            authors_year = parsed_name[:authorship][:year] if parsed_name[:authorship]
            
            author_source = from_source.to_s
        else
    
            authors_joined = name_to_use[:authorship][:normalized] if name_to_use[:authorship]
            authors_year = name_to_use[:authorship][:year] if name_to_use[:authorship]
            
            author_source = 'gbol'
        end
    
        # num_german_barcodes = 0
        # only_gbol_barcodes = []
        # value.drop(1).each do |spec|
        #     next unless spec.country == 'Germany'
        #     # localities.push(spec.country)
        #     country = spec.country
        #     gbol_ids.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id
        #     bold_ids.push(spec.other_catalogue_id) if spec.other_catalogue_id
        #     only_gbol_barcodes.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id && spec.barcode_available && !spec.other_catalogue_id
        # end
    
        # num_german_barcodes += only_gbol_barcodes.size
    
    
        ## TODO: this does not impement search for authors... or stem or etc...
        # bold_ids.push(bold_ids_from_bold_dl.ids.flatten) if bold_ids_from_bold_dl
        # bold_ids = bold_ids.compact.flatten.uniq
        # num_german_barcodes += bold_ids.size
    
        # byebug if key_for_filtered =~ /Aloconota longicollis/
    
    
        # byebug if key =~ /Aloconota insecta/
    
    
        ## TODO: since i downloaded from bold just records from germany, this is actually ok. 
        # BUT should be changed later on... the info should come form the specimen record country info
        # country = 'Germany' if country.nil? && bold_ids_from_bold_dl
    
        output = OpenStruct.new(
            date:'12.02.2021',
            phylum: phylum,
            classis: classis,
            ordo: ordo,
            familia: familia,
            genus: genus,
            species: canonical_name,
            authors: authors_joined,
            year: authors_year,
            # localities: localities.compact.uniq.join(','),
            country: country,
            lineage_source: lineage_source,
            author_source: author_source
            # links: 'TODO',
            # num_german_barcodes: num_german_barcodes,
            # genbank_ids: 'TODO',
            # gbol_ids: gbol_ids.compact.flatten.uniq.join(','),
            # bold_ids: bold_ids.compact.flatten.uniq.join(',')
        )
    
        outputs.push(output)
    end
    
    return outputs
end


def print_outputs(file:, outputs:)

    sorted = outputs.sort_by(&:species)
    
    file.puts "id\tdate\tphylum\tclass\torder\tfamily\tgenus\tspecies\tauthorship\tyear\tcountry\tnum_barcodes\tlineage_source\tauthor_source"
    sorted.each do |out|
        file.print "#{out.id}\t"
        file.print "#{out.date}\t"
        file.print "#{out.phylum}\t"
        file.print "#{out.classis}\t"
        file.print "#{out.ordo}\t"
        file.print "#{out.familia}\t"
        file.print "#{out.genus}\t"
        file.print "#{out.species}\t"
        file.print "#{out.authors}\t"
        file.print "#{out.year}\t"
        file.print "#{out.country}\t"
        file.print "#{out.num_barcodes}\t"
        file.print "#{out.lineage_source}\t"
        file.puts "#{out.author_source}"
        # print "#{out.links}\t"
        # print "#{out.genbank_ids}\t"
        # print "#{out.gbol_ids}\t"
        # puts "#{out.bold_ids}"
    end
end


def print_specimen_outputs(file:, outputs:)
    
    file.puts "id\tdate\tspecies\tspecimen_id\tspecimen_source\tlink"

    outputs.each do |obj|
        file.print obj.id, "\t"
        file.print obj.species_name, "\t"
        file.print obj.date, "\t"
        file.print obj.specimen_id, "\t"
        file.print obj.specimen_source, "\t"
        file.print obj.link, "\n"
    end
end


# gbif_outputs = create_outputs(occurence_of_taxon: occurence_of_taxon, from_source: :gbif)
# ncbi_outputs = create_outputs(occurence_of_taxon: occurence_of_taxon, from_source: :ncbi)


# create_specimen_output(occurence_of_taxon:occurence_of_taxon, gbol_specimens_of: gbol_specimens_of)


specimen_output_file        = File.open('specimens2.tsv', 'w')
species_list_output_file    = File.open("species_list2.tsv", 'w')


create_outputs2(species_list_out: species_list_output_file, specimen_out: specimen_output_file, occurence_of_taxon: occurence_of_taxon, gbol_specimens_of: gbol_specimens_of, midori_specimens_of: midori_specimens_of, bold_specimens_of: bold_specimens_of)


exit



# species_list_outputs, specimen_outputs = create_outputs2(occurence_of_taxon: occurence_of_taxon, gbol_specimens_of: gbol_specimens_of, midori_specimens_of: midori_specimens_of)

# specimen_output_file = File.open('specimens.txt', 'w')
# print_specimen_outputs(file: specimen_output_file, outputs: specimen_outputs)

# combined_output_file      = File.open("__combined_out2.tsv", 'w')
# print_outputs(file: combined_output_file, outputs: species_list_outputs)




exit
# gbif_output_file      = File.open("__gbif_out.tsv", 'w')
# ncbi_output_file      = File.open("__ncbi_out.tsv", 'w')

# print_outputs(file: gbif_output_file, outputs: gbif_outputs)
# print_outputs(file: ncbi_output_file, outputs: ncbi_outputs)

# print_outputs(file: combined_output_file, outputs: (gbif_outputs | ncbi_outputs))

exit

occurence_of_taxon.each do |key, value|
    name_to_use = value.shift
    # bold_ids_from_bold_dl = value.last.is_a?(BoldIds) ? value.pop : nil

    full_normalized_name = name_to_use[:normalized]
    canonical_name = name_to_use[:canonical][:full]
    canonical_name_normalized = Helper.normalize(canonical_name)

    # puts full_normalized_name

    ## Homonym check?
    ##

    phylum = nil
    classis = nil
    ordo = nil
    familia = nil
    genus = nil
    species = nil
    author = nil
    year = nil
    # localities = []
    country = 'Germany'
    links = []
    genbank_ids = []
    gbol_ids = []
    bold_ids = []

    nomial = Nomial.new(parsed_name: name_to_use, query_taxon_name: 'Insecta', are_synonyms_allowed: true)
    gbif_obj = nomial.gbif_taxonomy_backbone(first_specimen_info: occurence_of_taxon[key].last)
    ncbi_obj = nomial.ncbi_taxonomy(first_specimen_info: occurence_of_taxon[key].last)

    not_found_gbif.puts key if gbif_obj.nil?
    not_found_ncbi.puts key if ncbi_obj.nil?

    next if obj.nil?
    next unless obj.taxon_rank =~ /species/

    phylum = obj.phylum
    classis = obj.classis
    ordo = obj.ordo
    familia = obj.familia
    genus = obj.genus
    species =  obj.canonical_name
    species =  key
    # authors_joined = name_to_use[:authorship][:authors].join(' & ') if name_to_use[:authorship]

    if value.first.source == 'MISSING_GBOL'
        parsed_name = Biodiversity::Parser.parse(obj.scientific_name)
        next unless parsed_name[:parsed]

        authors_joined = parsed_name[:authorship][:normalized] if parsed_name[:authorship]
        authors_year = parsed_name[:authorship][:year] if parsed_name[:authorship]
    else

        authors_joined = name_to_use[:authorship][:normalized] if name_to_use[:authorship]
        authors_year = name_to_use[:authorship][:year] if name_to_use[:authorship]
    end

    # num_german_barcodes = 0
    # only_gbol_barcodes = []
    # value.each do |spec|
    #     next unless spec.country == 'Germany'
    #     # localities.push(spec.country)
    #     country = spec.country
    #     gbol_ids.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id
    #     bold_ids.push(spec.other_catalogue_id) if spec.other_catalogue_id
    #     only_gbol_barcodes.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id && spec.barcode_available && !spec.other_catalogue_id
    # end

    # num_german_barcodes += only_gbol_barcodes.size


    ## TODO: this does not impement search for authors... or stem or etc...
    # bold_ids.push(bold_ids_from_bold_dl.ids.flatten) if bold_ids_from_bold_dl
    # bold_ids = bold_ids.compact.flatten.uniq
    # num_german_barcodes += bold_ids.size

    # byebug if key_for_filtered =~ /Aloconota longicollis/


    # byebug if key =~ /Aloconota insecta/


    ## TODO: since i downloaded from bold just records from germany, this is actually ok. 
    # BUT should be changed later on... the info should come form the specimen record country info
    # country = 'Germany' if country.nil? && bold_ids_from_bold_dl

    output = OpenStruct.new(
        date:'12.02.2021',
        phylum: phylum,
        classis: classis,
        ordo: ordo,
        familia: familia,
        genus: genus,
        species: canonical_name,
        authors: authors_joined,
        year: authors_year,
        # localities: localities.compact.uniq.join(','),
        country: country
        # links: 'TODO',
        # num_german_barcodes: num_german_barcodes,
        # genbank_ids: 'TODO',
        # gbol_ids: gbol_ids.compact.flatten.uniq.join(','),
        # bold_ids: bold_ids.compact.flatten.uniq.join(',')
    )

    outputs.push(output)
end
# puts "date\tphylum\tclass\torder\tfamily\tgenus\tspecies\tauthors\tyear\tlocalities\tlinks\tgenbank_ids\tgbol_ids\tbold_ids"
# p


puts "date\tphylum\tclass\torder\tfamily\tgenus\tspecies\tauthors\tyear\tcountry"
outputs.each do |out|
    print "#{out.date}\t"
    print "#{out.phylum}\t"
    print "#{out.classis}\t"
    print "#{out.ordo}\t"
    print "#{out.familia}\t"
    print "#{out.genus}\t"
    print "#{out.species}\t"
    print "#{out.authors}\t"
    print "#{out.year}\t"
    puts "#{out.country}\t"
    # print "#{out.localities}\t"
    # print "#{out.links}\t"
    # print "#{out.num_german_barcodes}\t"
    # print "#{out.genbank_ids}\t"
    # print "#{out.gbol_ids}\t"
    # puts "#{out.bold_ids}"
end



exit


filtered_name_entries_of = Filter.select_names(occurence_of_taxon: occurence_of_taxon)

bold_specimens_of = nil
if params[:bold_specimen_data]
    bold_download_file_name =  params[:bold_specimen_data]
    abort "file #{bold_download_file_name} does not exist, pleas provide valid GBOL Species List" unless File.file?(bold_download_file_name)
    
    bold_specimens_of =  BoldCombinedParser.new(file_name:bold_download_file_name, query_taxon_object: query_taxon_object).run
    # Barcodes.add_bold_ids(from_hash: bold_specimens_of, to_hash: filtered_name_entries_of)
end








outputs = []

filtered_name_entries_of.each do |key, value|
    name_to_use = value.shift
    bold_ids_from_bold_dl = value.last.is_a?(BoldIds) ? value.pop : nil

    full_normalized_name = name_to_use[:normalized]
    canonical_name = name_to_use[:canonical][:full]
    canonical_name_normalized = Helper.normalize(canonical_name)

    # puts full_normalized_name

    ## Homonym check?
    ##

    phylum = nil
    classis = nil
    ordo = nil
    familia = nil
    genus = nil
    species = nil
    author = nil
    year = nil
    # localities = []
    country = nil
    links = []
    genbank_ids = []
    gbol_ids = []
    bold_ids = []

    nomial = Nomial.new(parsed_name: name_to_use, query_taxon_name: 'Insecta', are_synonyms_allowed: true)
    # gbif_record = nomial.gbif_taxonomy_backbone(first_specimen_info: value.first)
    # ncbi_record = nomial.ncbi_taxonomy(first_specimen_info: value.first)

    # new_start_time = Time.now
    # time_between_request = new_start_time - old_start_time
    # request_time_added += time_between_request
    # request_num += 1

    # efetch_result = NcbiApi.new(taxon_name: canonical_name_normalized).efetch
    # pp efetch_result
    # sleep 0.1
    
    gbif_records = GbifTaxonomy.where(canonical_name: canonical_name_normalized)
    accepted_gbif_records = gbif_records.select { |r| r.taxonomic_status =~ /accepted/ }
    next if accepted_gbif_records.empty?


    next unless accepted_gbif_records.first.taxon_rank =~ /species/

    phylum = accepted_gbif_records.first.phylum
    classis = accepted_gbif_records.first.classis
    ordo = accepted_gbif_records.first.ordo
    familia = accepted_gbif_records.first.familia
    genus = accepted_gbif_records.first.genus
    species = accepted_gbif_records.first.canonical_name
    # authors_joined = name_to_use[:authorship][:authors].join(' & ') if name_to_use[:authorship]
    authors_joined = name_to_use[:authorship][:normalized] if name_to_use[:authorship]
    authors_year = name_to_use[:authorship][:year] if name_to_use[:authorship]


    # obj = OpenStruct.new(
    #     ident_name: ident_name,
    #     ident_gbif_taxon_id: nil,
    #     accepted_name: nil,
    #     accepted_gbif_taxon_id: nil,
    #     lineage: lineage,
    #     gbol_catalogue_id: gbol_catalogue_id,
    #     country: country,
    #     other_catalogue_id: other_catalogue_id,
    #     barcode_available: barcode_available,
    #     source: 'GBOL',
    # )

    num_german_barcodes = 0
    only_gbol_barcodes = []
    value.each do |spec|
        next unless spec.country == 'Germany'
        # localities.push(spec.country)
        country = spec.country
        gbol_ids.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id
        bold_ids.push(spec.other_catalogue_id) if spec.other_catalogue_id
        only_gbol_barcodes.push(spec.gbol_catalogue_id) if spec.gbol_catalogue_id && spec.barcode_available && !spec.other_catalogue_id
    end

    num_german_barcodes += only_gbol_barcodes.size


    ## TODO: this does not impement search for authors... or stem or etc...
    bold_ids.push(bold_ids_from_bold_dl.ids.flatten) if bold_ids_from_bold_dl
    bold_ids = bold_ids.compact.flatten.uniq
    num_german_barcodes += bold_ids.size

    # byebug if key_for_filtered =~ /Aloconota longicollis/


    # byebug if key =~ /Aloconota insecta/


    ## TODO: since i downloaded from bold just records from germany, this is actually ok. 
    # BUT should be changed later on... the info should come form the specimen record country info
    country = 'Germany' if country.nil? && bold_ids_from_bold_dl

    output = OpenStruct.new(
        date:'12.02.2021',
        phylum: phylum,
        classis: classis,
        ordo: ordo,
        familia: familia,
        genus: genus,
        species: canonical_name,
        authors: authors_joined,
        year: authors_year,
        # localities: localities.compact.uniq.join(','),
        country: country,
        # links: 'TODO',
        num_german_barcodes: num_german_barcodes,
        genbank_ids: 'TODO',
        gbol_ids: gbol_ids.compact.flatten.uniq.join(','),
        bold_ids: bold_ids.compact.flatten.uniq.join(',')
    )

    outputs.push(output)
end
# puts "date\tphylum\tclass\torder\tfamily\tgenus\tspecies\tauthors\tyear\tlocalities\tlinks\tgenbank_ids\tgbol_ids\tbold_ids"
# puts "date\tphylum\tclass\torder\tfamily\tgenus\tspecies\tauthors\tyear\tlocalities\tgenbank_ids\tgbol_ids\tbold_ids"
# puts "date\tphylum\tclass\torder\tfamily\tgenus\tspecies\tauthors\tyear\tcountry\tgenbank_ids\tgbol_ids\tbold_ids"
puts "date\tphylum\tclass\torder\tfamily\tgenus\tspecies\tauthors\tyear\tcountry\tnum_german_barcodes\tgenbank_ids\tgbol_ids\tbold_ids"
outputs.each do |out|
    print "#{out.date}\t"
    print "#{out.phylum}\t"
    print "#{out.classis}\t"
    print "#{out.ordo}\t"
    print "#{out.familia}\t"
    print "#{out.genus}\t"
    print "#{out.species}\t"
    print "#{out.authors}\t"
    print "#{out.year}\t"
    print "#{out.country}\t"
    # print "#{out.localities}\t"
    # print "#{out.links}\t"
    print "#{out.num_german_barcodes}\t"
    print "#{out.genbank_ids}\t"
    print "#{out.gbol_ids}\t"
    puts "#{out.bold_ids}"
end
