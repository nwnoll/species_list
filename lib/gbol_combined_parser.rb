# frozen_string_literal: true

class GbolCombinedParser
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :query_taxon_name

  def self.get_source_lineage(row)
    OpenStruct.new(
      name:     row["Species"],
      combined: row['HigherTaxa'].split(', ')
    )
  end

  def initialize(file_name:, query_taxon_object:)
    @file_name                = Pathname.new(file_name)
    @query_taxon_object       = query_taxon_object
    @query_taxon_name         = query_taxon_object.canonical_name
    @query_taxon_rank         = query_taxon_object.taxon_rank
  end

  def run
    specimens_of_taxon  = Hash.new { |hash, key| hash[key] = {} }
    Helper.extract_zip(name: file_name, destination: file_name.dirname, files_to_extract: [file_name.basename.sub_ext('.csv').to_s, 'metadata.xml'])
    
    
    csv_file_name = file_name.sub_ext('.csv')
    csv_file = File.open(csv_file_name, 'r')
    csv_object = CSV.new(csv_file, headers: true, col_sep: "\t", liberal_parsing: true)


    csv_object.each do |row|
      _matches_query_taxon(row) ? nil : next

      specimen = _get_specimen(row: row)
      next if specimen.nil?

      SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
    end

    return specimens_of_taxon
  end
  
  private
  def _get_specimen(row:)
    identifier                    = row["CatalogueNumber"]
    source_taxon_name             = row["Species"]
    # sequence                      = row['BarcodeSequence']
    sequence                      = nil
    location                      = row["Location"]
    lat                           = row["Latitude"]
    long                          = row["Longitude"]
    link                          = row["UUID"]

    id_ary = identifier.split(';')
    other_identifier = nil
    if id_ary.size > 1
      other_identifier = id_ary.pop
      identifier = id_ary.pop
    end
    ## TODO:
    ## NEXT:
    ## split cataloguenumber since here are multuple ids...
    ## first one seems to be always be the gbol one

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
    specimen.location             = location
    specimen.lat                  = lat
    specimen.long                 = long
    specimen.link                 = link
    specimen.first_specimen_info  = row
    
    return specimen
  end

  def _matches_query_taxon(row)
    /#{query_taxon_name}/.match?(row["HigherTaxa"]) || /#{query_taxon_name}/.match?(row["Species"])
  end
end
