# frozen_string_literal: true

class BoldCombinedParser
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :query_taxon_name

  @@index_by_column_name = nil
  def initialize(file_name:, query_taxon_object:)
    @file_name            = file_name
    @query_taxon_object   = query_taxon_object
    @query_taxon_name     = query_taxon_object.canonical_name
    @query_taxon_rank     = query_taxon_object.taxon_rank
  end

  def run
    specimens_of_taxon    = Hash.new { |hash, key| hash[key] = {} }
    
    file                  = File.file?(file_name) ? File.open(file_name, 'r') : nil
    abort "#{file_name} is not a valid file" if file.nil?
    
    @@index_by_column_name = Helper.generate_index_by_column_name(file: file, separator: "\t")

    # p 'starting to populate'
    file.each do |row|
      # puts file.lineno
      _matches_query_taxon(row.scrub!) ? nil : next

      scrubbed_row = row.scrub!.chomp.split("\t")

      specimen = _get_specimen(row: scrubbed_row)
      next if specimen.nil?

      SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
    end

    return specimens_of_taxon
  end

  private
  def _get_specimen(row:)
    identifier                    = row[@@index_by_column_name["processid"]]
    source_taxon_name             = SpecimensOfTaxon.find_lowest_ranking_taxon(row, @@index_by_column_name)
    # sequence                      = row[@@index_by_column_name['nucleotides']]
    sequence                      = nil
    # sequence                      = Helper.filter_seq(sequence, filter_params)
    marker                        = row[@@index_by_column_name["markercode"]]
    other_identifier              = row[@@index_by_column_name["institution_storing"]] == 'Mined from GenBank, NCBI' ? row[@@index_by_column_name["genbank_accession"]] : nil

    return nil unless _belongs_to_correct_marker?(marker)
    # return nil if sequence.nil?

    # nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)

    specimen                      = Specimen.new
    specimen.identifier           = identifier
    specimen.other_identifier     = other_identifier
    specimen.sequence             = sequence
    specimen.source_taxon_name    = source_taxon_name
    # specimen.taxon_name           = nomial.name
    specimen.taxon_name           = source_taxon_name
    # specimen.nomial               = nomial
    specimen.first_specimen_info  = row
    specimen.location             = row[@@index_by_column_name["country"]]
    
    return specimen
  end

  def _belongs_to_correct_marker?(marker)
    marker == 'COI-5P'
  end

  def self.get_source_lineage(row)
    lineage_ary = SpecimensOfTaxon.create_lineage_ary(row, @@index_by_column_name)
    
    OpenStruct.new(
      name: SpecimensOfTaxon.find_lowest_ranking_taxon(row, @@index_by_column_name),
      combined: lineage_ary
    )
  end

  def _matches_query_taxon(row)
    /#{query_taxon_name}/.match?(row)
  end
end