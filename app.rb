require "rubygems"

require "intermine/service"
require "sinatra"
require "haml"
require "json"

require "./lib/intermine/jbrowse/data"
require "./lib/intermine/jbrowse/model"

set :haml, :format => :html5

FLYMINE = InterMine::JBrowse::Adaptor.new("www.flymine.org/query", 7227)

# Common control methods shared by HTML and JSON outputs

def get_refseq_feature(name, segment = {})
    seq = FLYMINE.sequence(name, "Chromosome", segment)
    [ InterMine::JBrowse::ReferenceSequence.new(segment, seq) ]
end

def get_features(name, segment)
    fs = FLYMINE.features(name, "Chromosome", (segment[:type] || "SequenceFeature"), segment)
    fs.map {|f| InterMine::JBrowse::Feature.new(f) }
end

# The routes useful for graphical inspection of the app.

get "/" do
    haml :index, :locals => {
        :global_stats => FLYMINE.global_stats
        :ref_seqs => FLYMINE.refseqs
    }
end

get "/:refseq" do |name|
    haml :refseq, :locals => {
        :segment => params,
        :refseq => FLYMINE.feature(name, {}, "Chromosome"),
        :stats => FLYMINE.stats(name, "Chromosome", params[:type], params)
    }
end

get "/:refseq/features" do |name|
    haml :features, :locals => {
        :segment => params,
        :refseq => FLYMINE.feature(name, {}, "Chromosome"),
        :features => get_features(name, params)
    }
end

get "/:refseq/residues" do |name|
    haml :sequence, :locals => {
        :sequence => FLYMINE.sequence(name, "Chromosome", params),
        :name => name,
        :segment => params
    }
end

# Routes to run a local JBrowse.

get "/jbrowse" do
    haml :jbrowse
end

# Aand here begin the routes required by the JBrowse REST Store API

get "/stats/global" do
    FLYMINE.global_stats.to_json
end

get "/stats/region/:refseq_name" do |name|
    FLYMINE.stats(name, "Chromosome", params[:type], params).to_json
end

get "/features/:refseq_name" do
    {:features => get_features(name, params)}.to_json
end
