# frozen_string_literal: true

class Nomial
  attr_reader :parsed_name, :query_taxon_name, :query_taxon_object, :query_taxon_rank, :are_synonyms_allowed, :name
  def initialize(parsed_name:, query_taxon_name:, query_taxon_object: nil, query_taxon_rank: nil, are_synonyms_allowed:)
    @parsed_name = parsed_name
    @query_taxon_name = query_taxon_name
    @query_taxon_object = GbifTaxonomy.find_by(canonical_name: 'Insecta')
    @query_taxon_rank = GbifTaxonomy.find_by(canonical_name: 'Insecta').taxon_rank
    @are_synonyms_allowed = are_synonyms_allowed
    @name = parsed_name[:canonical][:full]
  end

  def gbif_taxonomy_backbone(first_specimen_info:)
    records = _get_gbif_records(current_name: name, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)
    return record unless record.nil?

    name_stem = parsed_name[:canonical][:stemmed]
    records = _get_gbif_records(current_name: name_stem, first_specimen_info: first_specimen_info)
    record  = _gbif_taxonomy_object(records: records)

    return record unless record.nil?
  end

  def ncbi_taxonomy(first_specimen_info:)
    records = _get_ncbi_records(current_name: name, first_specimen_info: first_specimen_info)
    record  = _ncbi_taxonomy_object(records: records)
    return record unless record.nil?

    name_stem = parsed_name[:canonical][:stemmed]
    records = _get_ncbi_records(current_name: name_stem, first_specimen_info: first_specimen_info)
    record  = _ncbi_taxonomy_object(records: records)

    return record unless record.nil?
  end


  private
  def _gbif_taxonomy_object(records:)
    return nil if records.nil? || records.empty?

    accepted_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record, :gbif) && _is_accepted?(record) }
    return accepted_records.first if accepted_records.size > 0

    doubtful_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record, :gbif) && _is_doubtful?(record) }
    return doubtful_records.first if doubtful_records.size > 0

    if are_synonyms_allowed
      synonymous_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record, :gbif) && _is_synonym?(record) }
      return synonymous_records.first if synonymous_records.size > 0
    else
      synonymous_records = records.select { |record| _belongs_to_correct_query_taxon_rank?(record, :gbif) && _is_synonym?(record) && _has_accepted_name_usage_id(record) }
      return GbifTaxonomy.find_by(taxon_id: synonymous_records.first.accepted_name_usage_id.to_i) if synonymous_records.size > 0
    end

    return nil
  end

  def _ncbi_taxonomy_object(records:)
    return nil if records.nil? || records.empty?

    records = records.select { |record| NcbiTaxonomy.allowed_ranks.include?(record.taxon_rank) }

    return records.first
  end

  def _get_gbif_records(current_name:, first_specimen_info:)
    return nil if current_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?
    
    all_records = GbifTaxonomy.where(canonical_name: current_name)
    return nil if all_records.nil?

    records = _is_homonym?(current_name) ? _records_with_matching_lineage(current_name: current_name, lineage: first_specimen_info.lineage, all_records: all_records) : all_records

    return records
  end

  def _get_ncbi_records(current_name:, first_specimen_info:)
    return nil if current_name.nil? || query_taxon_object.nil? || query_taxon_rank.nil?

    ncbi_name_records         = NcbiName.where(name: current_name)
    usable_ncbi_name_records  = ncbi_name_records.select { |record| record.name_class == 'scientific name' || record.name_class == 'synonym' || record.name_class == 'includes' || record.name_class == 'authority' } # || record.name_class == 'in-part'  }
    return nil if usable_ncbi_name_records.empty?
    
    ncbi_taxonomy_objects = []

    usable_ncbi_name_records.each do |usable_ncbi_name_record|
      ncbi_tax_id = usable_ncbi_name_record.tax_id
      ncbi_name_records_for_tax_id = NcbiName.where(tax_id: ncbi_tax_id)
      next if ncbi_name_records_for_tax_id.empty?

      ncbi_ranked_lineage_record = NcbiRankedLineage.find_by(tax_id: ncbi_tax_id)
      next unless _belongs_to_correct_query_taxon_rank?(ncbi_ranked_lineage_record, :ncbi)

      ncbi_node_record = NcbiNode.find_by(tax_id: ncbi_tax_id)
      next if ncbi_node_record.nil?

      authority         = nil
      canonical_name    = nil
      genus             = nil
      taxonomic_status  = nil
      familia           = ncbi_node_record.rank == 'family'   ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.familia
      ordo              = ncbi_node_record.rank == 'order'    ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.ordo
      classis           = ncbi_node_record.rank == 'class'    ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.classis
      phylum            = ncbi_node_record.rank == 'phylum'   ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.phylum
      regnum            = ncbi_node_record.rank == 'kingdom'  ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.regnum

      if are_synonyms_allowed
        ## TODO:
        ## NEXT
        ## Problem here is that if I allow synonyms it will never use the authority information
        ## IMPORTANT change also in the db_merger

        scientifc_name_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'scientific name' }.first
        canonical_name = scientifc_name_record.nil? ? usable_ncbi_name_record.name : scientifc_name_record.name 

        authority_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'authority' }.first
        authority = authority_record.nil? ? canonical_name : authority_record.name

        taxonomic_status = _taxonomic_name(usable_ncbi_name_record)

        if ncbi_node_record.rank == 'species' || ncbi_node_record.rank == 'subspecies' || ncbi_node_record.rank == 'genus' 
          genus = usable_ncbi_name_record.name.split(' ')[0]
        end
      else
        scientifc_name_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'scientific name' }.first
        canonical_name = scientifc_name_record.name unless scientifc_name_record.nil?

        authority_record = ncbi_name_records_for_tax_id.select { |record| record.name_class == 'authority' }.first
        authority = authority_record.nil? ? canonical_name : authority_record.name

        genus = ncbi_node_record.rank == 'genus' ? ncbi_ranked_lineage_record.name : ncbi_ranked_lineage_record.genus

        taxonomic_status = _taxonomic_name(scientifc_name_record) unless scientifc_name_record.nil?
      end

      combined = _get_combined(ncbi_ranked_lineage_record, ncbi_node_record.rank)

      combined.push(genus)          if genus && !genus.empty?
      combined.push(canonical_name) unless combined.include?(canonical_name)

      obj = OpenStruct.new(
        taxon_id:               usable_ncbi_name_record.tax_id,
        regnum:                 regnum,
        phylum:                 phylum,
        classis:                classis,
        ordo:                   ordo,
        familia:                familia,
        genus:                  genus,
        canonical_name:         canonical_name,
        scientific_name:        authority,
        taxonomic_status:       taxonomic_status,
        taxon_rank:             ncbi_node_record.rank,
        combined:               combined,
        comment:                ''
      )

      ncbi_taxonomy_objects.push(obj)
    end

    records = _is_homonym?(current_name) ? _records_with_matching_lineage(current_name: current_name, lineage: first_specimen_info.lineage, all_records: ncbi_taxonomy_objects) : ncbi_taxonomy_objects

    return records
  end

  def _is_accepted?(record)
    record.taxonomic_status =~ /accepted/
  end 
  
  def _is_doubtful?(record)
    record.taxonomic_status =~ /doubtful/i
  end

  def _is_synonym?(record)
    record.taxonomic_status =~ /synonym|misapplied/i
  end

  def _is_homonym?(taxon_name)
    GbifHomonym.exists?(canonical_name: taxon_name)
  end

  def _has_accepted_name_usage_id(record)
    !record.accepted_name_usage_id.nil?
  end

  def _belongs_to_correct_query_taxon_rank?(record, taxonomy)
    if taxonomy == :gbif
      record.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name
    elsif taxonomy == :ncbi
      record.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name || record.name == query_taxon_name
    end
  end

  def has_scientific_name_in_ncbi?(record)
    record.taxonomic_status =~ /scientific name/
  end

  def is_authority_in_ncbi?(record)
    record.taxonomic_status =~ /authority/
  end

  def is_synonym_in_ncbi?(record)
    record.taxonomic_status =~ /synonym/
  end

  def is_includes_in_ncbi?(record)
    record.taxonomic_status =~ /includes/
  end

  def is_in_part_in_ncbi?(record)
    record.taxonomic_status =~ /in-part/
  end

  def _fuzzy_path
    'species/match?strict=true&name='
  end

  def _records_with_matching_lineage(current_name:, lineage:, all_records:)
    species_ranks             = ["subspecies", "variety", "form", "subvariety", "species"]
    genus_ranks               = ["genus"]
    family_ranks              = ["infrafamily", "family", "superfamily"]
    order_ranks               = ["infraorder", "order", "superorder"]
    class_ranks               = ["infraclass", "class", "superclass"]

    potential_correct_records = []
    all_records.each do |taxon_object|
      # lineage.combined.reverse.each do |taxon|
      lineage.reverse.each do |taxon|
        if species_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('genus')   == taxon
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('familia') == taxon
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon
        elsif genus_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('familia') == taxon
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon
        elsif family_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('ordo')    == taxon
        elsif order_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('classis') == taxon
        elsif class_ranks.include? taxon_object.taxon_rank
          potential_correct_records.push(taxon_object) and break if taxon_object.public_send('phylum')  == taxon
        end
      end
    end

    return potential_correct_records
  end

  def _get_combined(record, rank_of_record)
    combined = []
    possible_ranks = NcbiTaxonomy.ranks_for_combined

    possible_ranks.reverse.each do |rank|
      rank_info = rank_of_record == rank ? record.name : record.public_send(Helper.latinize_rank(rank))
      combined.push(rank_info) unless rank_info.blank?
    end

    return combined
  end

  def _taxonomic_name(record)
    return if record.nil?

    if record.name_class == 'scientific name'
      return 'accepted'
    elsif record.name_class == 'synonym'
      return 'synonym'
    elsif record.name_class == 'includes'
      return 'synonym'
    elsif record.name_class == 'in-part' ## UNUSED atm
      return 'synonym'
    end
  end


end
