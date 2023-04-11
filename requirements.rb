# frozen_string_literal: true

require "bundler"
require "active_record"
require "sqlite3"
require 'bio'
require 'zip'
require 'biodiversity'

require "yaml"
require 'optparse'
require 'json'
require 'pp'
require 'open-uri'
require 'net/ftp'
require 'net/http'
require 'csv'
require 'fileutils'
require 'pathname'
require 'ostruct'
require 'timeout'
require 'digest/md5'
require 'time'
require 'rexml/document'

require_relative "db/database_schema"
require_relative "lib/nomial"
require_relative 'lib/helper'
require_relative 'lib/ncbi_api'
require_relative 'lib/http_downloader'
require_relative 'lib/specimens_of_taxon'
require_relative 'lib/specimen'
require_relative 'lib/bold_combined_parser'
require_relative 'lib/taxon_occurence_parser'
require_relative 'lib/filter'
require_relative 'lib/barcodes'
require_relative 'lib/gbol_combined_parser'
require_relative 'lib/midori_fasta_parser'

# require_relative 'lib/output_formats/output_format'

Dir[File.dirname(__FILE__) + "/lib/models/*.rb"].each do |file|
    # puts File.basename(file, File.extname(file))
    require_relative "lib/models/#{File.basename(file, File.extname(file))}"
end

Bundler.require

db_config_file 	= File.open("db/database.yaml")
db_config 		= YAML::load(db_config_file)

if File.exists?(db_config['database'])
	ActiveRecord::Base.establish_connection(db_config)
else
	ActiveRecord::Base.establish_connection(db_config)
	DatabaseSchema.create_db
end


unless GbifTaxonomy.any?
	puts "GBIF Taxonomy is not setup yet, downloading and importing GBIF Taxonomy, this may take a while."
	
	gbif_taxonomy_job = GbifTaxonomyJob.new
	gbif_taxonomy_job.run
end

unless NcbiRankedLineage.any? || NcbiName.any? || NcbiNode.any?
	puts "NCBI Taxonomy is not setup yet, downloading and importing NCBI Taxonomy, this may take a while."
	
	ncbi_taxonomy_job = NcbiTaxonomyJob.new(config_file_name: 'lib/configs/ncbi_taxonomy_config.json')
	ncbi_taxonomy_job.run
end

unless GbifHomonym.any?
	GbifHomonymImporter.new(file_name: 'homonyms.txt').run
end
