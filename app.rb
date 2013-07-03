require "rubygems"

require "intermine/service"
require "sinatra"
require "haml"
require "json"

require "./lib/intermine/jbrowse/data"

set :haml, :format => :html5

FLYMINE = InterMine::JBrowse::Adaptor.new("www.flymine.org/query", 7227)

def get_refseq(name, segment = {})
    q = FLYMINE.query("Chromosome").select("*").
        where(:primaryIdentifier => name, "organism.taxonId" => 7227)

    if segment and segment[:sequence]
        q.add_to_select("sequence.residues")
    end

    q.first
end

SEQ_CACHE = {}

def get_refseq_residues(name, segment = {})
    if SEQ_CACHE[name].nil?
        puts "Fetching sequence data for #{ name }"
        chrom = get_refseq(name, {:sequence => true})
        SEQ_CACHE[name] = chrom.sequence.residues
    end
    puts "Reading sequence from cache"
    seq = SEQ_CACHE[name]
    s = segment[:start] or 0
    e = segment[:end] or seq.size
    len = e.to_i - s.to_i

    seq[s.to_i, len]
end

def get_range(name, segment = {})
    if segment.nil?
        return nil
    elsif segment[:start].nil? and segment[:end].nil?
        return nil
    elsif segment[:start].nil? or segment[:end].nil?
        return "#{name}:#{segment[:start] or segment[:end]}"
    else
        return "#{name}:#{segment[:start]}..#{segment[:end]}"
    end
end

def get_segment_length(name, segment = {})
    if segment[:start].nil? and segment[:end].nil?
        return get_refseq(name).length
    elsif segment[:start].nil? or segment[:end].nil?
        if segment[:start].nil?
            return segment[:end].to_i
        else
            return get_refseq(name).length - segment[:start].to_i
        end
    else
        return segment[:end].to_i - segment[:start].to_i
    end
end

def get_refseq_stats(name, segment = {})
    feature_q = FLYMINE.new_query("SequenceFeature").
        select(:id).
        where("chromosome.primaryIdentifier" => name)

    range = get_range(name, segment)
    segment_length = get_segment_length(name, segment)

    unless range.nil?
        feature_q = feature_q.where("chromosomeLocation" => {:OVERLAPS => [range]})
    end

    feature_count = feature_q.count

    feature_density = feature_count.to_f / segment_length.to_f
    
    {:featureCount => feature_count, :featureDensity => feature_density}
end

module Hashlike

    def to_json(*a)
        self.to_h.to_json(*a)
    end

end

class JBrowseFeature
    include Hashlike
    attr_accessor :type, :name, :uniqueID, :start, :end, :strand

    def initialize(locatedFeature)
        feature = locatedFeature.feature
        @type = feature.sequenceOntologyTerm.name
        @name = feature.name or feature.symbol
        @uniqueID = feature.primaryIdentifier
        @start = locatedFeature.start
        @end = locatedFeature.end
        @strand = locatedFeature.strand
    end

    def to_h
        {
            :type => @type, :name => @name, :uniqueID => @uniqueID, :start => @start,
            :end => @end, :strand => @end
        }
    end

end

class RefSeqFeature

    include Hashlike
    attr_accessor :start, :end, :seq

    def initialize(segment, seq)
        @seq = seq
        @start = segment[:start] or 0
        @end = segment[:end]
    end

    def to_h
        {:start => @start, :end => @end, :seq => @seq}
    end

end

class JBrowseMainFeature < JBrowseFeature
    attr_accessor :subfeatures

    def initialize(locatedFeature)
        super(locatedFeature)
        feature = locatedFeature.feature
        if feature.nil?
            raise "This location has no feature! #{ locatedFeature }"
        end
        child_features = feature.locatedFeatures
        if child_features.nil?
            @subfeatures = []
        else
            @subfeatures = child_features.map {|sf| JBrowseFeature.new(sf)}
        end
    end

    def to_h
        super.merge({:subfeatures => @subfeatures.map(&:to_h)})
    end
end

def get_refseq_feature(name, segment = {})
    seq = get_refseq_residues(name, segment)
    [ RefSeqFeature.new(segment, seq) ]
end

def get_features(name, segment = {})

    if segment[:featuretype] == "Chromosome"
        return get_refseq_feature(name, segment)
    end

    feature_type = {:sub_class => (segment[:featuretype] or "SequenceFeature")}
    q = FLYMINE.new_query("Chromosome").
        where("locatedFeatures.feature" => feature_type).
        select("primaryIdentifier",
               "locatedFeatures.*",
               "locatedFeatures.feature.*",
               "locatedFeatures.feature.sequenceOntologyTerm.name").
        where("organism.taxonId" => 7227, :primaryIdentifier => name).
        outerjoin("locatedFeatures")

    if segment[:sequence]
        q.add_to_select("locatedFeatures.sequence.residues")
    end

    if segment[:subfeatures]
        q = q.
            where("locatedFeatures.feature.locatedFeatures.feature" => feature_type).
            add_to_select(
               "locatedFeatures.feature.locatedFeatures.*",
               "locatedFeatures.feature.locatedFeatures.feature.*",
               "locatedFeatures.feature.locatedFeatures.feature.sequenceOntologyTerm.name").
            outerjoin("locatedFeatures.feature.locatedFeatures")
    end

    range = get_range(name, segment)

    q = q.where("locatedFeatures" => {:OVERLAPS => [range]}) unless range.nil?

    chrom = q.all.first
    if chrom.nil?
        puts "No chromosome found"
        return []
    else
        return chrom.locatedFeatures.map {|f| JBrowseMainFeature.new(f)}
    end
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
