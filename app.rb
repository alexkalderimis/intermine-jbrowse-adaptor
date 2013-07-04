require "rubygems"

require "intermine/service"
require "sinatra"
require "haml"
require "json"

require "./lib/intermine/jbrowse/data"
require "./lib/intermine/jbrowse/model"

set :haml, :format => :html5

SERVICE_URL = "http://beta.flymine.org/beta"
ORGANISM = 7227

FLYMINE = InterMine::JBrowse::Adaptor.new(SERVICE_URL, ORGANISM)

# Common control methods shared by HTML and JSON outputs

def get_refseq_feature(name, segment = {})
    seq = FLYMINE.sequence(name, "Chromosome", segment)
    [ InterMine::JBrowse::ReferenceSequence.create(segment, seq) ]
end

def get_features(name, segment = {})
    if segment[:sequence] and segment[:type] == "Chromosome"
        return get_refseq_feature(name, segment)
    end

    fs = FLYMINE.features(name, "Chromosome", (segment[:type] || "SequenceFeature"), segment)
    fs.map {|f| InterMine::JBrowse::Feature.create(f) }
end

# The routes useful for graphical inspection of the app.

get "/" do
    haml :index, :locals => {
        :global_stats => FLYMINE.global_stats,
        :ref_seqs => FLYMINE.refseqs
    }
end

get "/:refseq" do |name|
    haml :refseq, :locals => {
        :segment => params,
        :refseq => FLYMINE.feature(name, {}, "Chromosome"),
        :stats => FLYMINE.stats(name, "Chromosome", (params[:type] || "SequenceFeature"), params)
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
    haml :jbrowse, :locals => {
        :service_url => SERVICE_URL
    }
end

get "/trackList.json" do
    model = Service.new(SERVICE_URL).model
    seq_feature = model.table("SequenceFeature")
    feature_tracks = model.classes.select{|c| c.subclass_of? seq_feature}.map do |c|
        {
            :label => "#{ c.name }_track",
            :key => "#{ c.name }s",
            :type => "JBrowse/View/Track/HTMLFeatures",
            :storeClass => "JBrowse/Store/SeqFeature/REST",
            :baseUrl => request.base_url,
            :query => { :type => c.name }
        }
    end

    reference_tracks = FLYMINE.refseqs.map do |refseq|
        {
            :label => "#{ refseq.primaryIdentifier }_sequence_track",
            :key => refseq.primaryIdentifier,
            :type => "JBrowse/View/Track/Sequence",
            :storeClass => "JBrowse/Store/SeqFeature/REST",
            :baseUrl => request.base_url,
            :query => { :sequence => true, :type => "Chromosome" }
        }
    end

    {:tracks => feature_tracks + reference_tracks}.to_json

end

get "/seq/refSeqs.json" do 
    FLYMINE.refseqs.map do |rs|
        {:name => rs.primaryIdentifier, :start => 0, :end => rs.length }
    end.to_json
end

# And here begin the routes required by the JBrowse REST Store API

get "/stats/global" do
    FLYMINE.global_stats.to_json
end

get "/stats/region/:refseq_name" do |name|
    FLYMINE.stats(name, "Chromosome", params[:type], params).to_json
end

get "/features/:refseq_name" do
    {:features => get_features(name, params)}.to_json
end
