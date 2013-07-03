require "rubygems"

require "intermine/service"
require "sinatra"
require "haml"
require "json"

require "./lib/intermine/jbrowse/data"
require "./lib/intermine/jbrowse/model"

set :haml, :format => :html5

FLYMINE = InterMine::JBrowse::Adaptor.new("www.flymine.org/query", 7227)


def get_refseq_feature(name, segment = {})
    seq = FLYMINE.sequence(name, "Chromosome", segment)
    [ ReferenceSequence.new(segment, seq) ]
end

def get_features(name, segment)
    fs = FLYMINE.features(name, "Chromosome", (segment[:type] || "SequenceFeature"), segment)
    fs.map {|f| InterMine::JBrowse::Feature.new(f) }
end

# The routes useful for graphical inspection of the app.

get "/" do
    haml :index, :locals => {
        :global_stats => get_global_stats,
        :ref_seqs => get_refseqs
    }
end

get "/:refseq" do |name|
    stats = get_refseq_stats(name, params)
    chrom = get_refseq(name)
    haml :refseq, :locals => {:segment => params, :refseq => chrom, :stats => stats}
end

get "/:refseq/features" do |name|
    chrom = get_refseq(name)
    features = get_features(name, params)
    haml :features, :locals => {:segment => params, :refseq => chrom, :features => features}
end

get "/:refseq/residues" do |name|
    puts "Getting residues for #{ name }"
    sequence = get_refseq_residues(name, params)
    haml :sequence, :locals => {:sequence => sequence, :name => name, :segment => params}
end

# Routes to run a local JBrowse.

get "/jbrowse" do
    haml :jbrowse
end

# Aand here begin the routes required by the JBrowse REST Store API

get "/stats/global" do
    get_global_stats.to_json
end

get "/stats/region/:refseq_name" do |name|
    get_refseq_stats(name, params).to_json
end

get "/features/:refseq_name" do
    {:features => get_features(name, params)}.to_json
end
