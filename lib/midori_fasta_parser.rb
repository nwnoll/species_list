# frozen_string_literal: true

class MidoriFastaParser
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
        
        fasta_file = File.open(file_name, 'r')

        header = nil
        seq_of = Hash.new
        fasta_file.each { |line| line =~ /^>/ ? header = line.chomp : seq_of.key?(header) ? seq_of[header] = nil : seq_of[header] = nil }
  
        seq_of.each do |key, value|
            _matches_query_taxon(key) ? nil : next
    
            specimen = _get_specimen(header: key, sequence: value)
            next if specimen.nil?

            SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
      end
  
      return specimens_of_taxon
    end
    
    private
    def _get_specimen(header:, sequence:)
        header =~ /^>(.*?)\.<.*?\t(.*?)$/
        id = $1
        lineage = $2

        lineage =~ /;species_(.*?)_.*?/
        species_name = $1

        # nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)
    
        specimen                      = Specimen.new
        specimen.identifier           = id
        specimen.sequence             = sequence
        specimen.source_taxon_name    = species_name
        # specimen.taxon_name           = nomial.name
        specimen.taxon_name           = species_name
        # specimen.nomial               = nomial
        specimen.link                 = "https://www.ncbi.nlm.nih.gov/nuccore/#{id}"
        specimen.first_specimen_info  = header
        
        return specimen
    end
  
    def _matches_query_taxon(header)
      /#{query_taxon_name}/.match?(header)
    end
  end
  