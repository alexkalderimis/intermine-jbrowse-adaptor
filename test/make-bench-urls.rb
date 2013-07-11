require "intermine/service"
require "yaml"
require "./lib/intermine/jbrowse/data"

class UrlGenerator

    def initialize(api_base, n_urls, label, conf)
        @api_base = api_base
        @n_urls = n_urls
        @adaptor = InterMine::JBrowse::Adaptor.new conf
        @label = label
    end

    def n_random_regions(len = nil)
        (1 .. @n_urls).each do
            if len.nil?
                yield
            else
                yield [rand(len), rand(len)].map{|n| n + 1}.sort
            end
        end
    end

    def print_global_stats_urls
        n_random_regions do
            puts "#{ @api_base }/#{ @label }/stats/global"
        end
    end

    def rand_type
        @types ||= @adaptor.sequence_types
        @types[rand(@types.size)].name
    end

    def print_region_urls
        @adaptor.refseqs.select(&:length).each do |refseq|
            len = refseq.length
            chr = refseq.primaryIdentifier
            n_random_regions(len) do |s, e|
                method = "stats/region"
                t = rand_type
                puts "#{ @api_base }/#{ @label }/#{ method }/#{ chr }?start=#{s}&end=#{e}&type=#{t}"
            end
            n_random_regions(len) do |s, _|
                method = "features"
                e = [s + 1000, len].min
                t = rand_type
                puts "#{ @api_base }/#{ @label }/#{ method }/#{ chr }?start=#{s}&end=#{e}&type=#{t}"
            end
            n_random_regions(len) do |s, _|
                e = [s + 1000, len].min
                method = "features"
                t = "Chromosome"
                puts "#{ @api_base }/#{ @label }/#{ method }/#{ chr }?start=#{s}&end=#{e}&type=#{t}&sequence=true"
            end
        end
    end

    def generate!
        print_global_stats_urls
        print_region_urls
    end
end

api_base, n_urls = ARGV
n_urls = n_urls ? n_urls.to_i : 1
config = YAML::load_file "config.yml"

config["services"].each do |label, conf|
    generator = UrlGenerator.new api_base, n_urls, label, conf
    generator.generate!
end


