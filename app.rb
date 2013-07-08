require "rubygems"

require "intermine/service"
require "sinatra/base"
require "sinatra/config_file"
require "sinatra/respond_with"
require "haml"
require "json"
require "multi_json"

require "./lib/intermine/jbrowse/data"
require "./lib/intermine/jbrowse/model"

class JBrowsify < Sinatra::Base

    register Sinatra::ConfigFile
    register Sinatra::RespondWith

    config_file "config.yml"

    ADAPTORS = Hash.new
    
    before do
        if JBrowsify::ADAPTORS.empty?
            puts settings.services
            adaptors = settings.services.map do |n, s|
                [n, InterMine::JBrowse::Adaptor.new(s)]
            end
            JBrowsify::ADAPTORS.update Hash[adaptors]
        end
    end

    # Common control methods shared by HTML and JSON outputs

    def adaptor(name)
        ADAPTORS[name] or halt 404
    end
    
    def short_segment(service, refseq)
        adaptor(service).short_segment(refseq, params)
    end

    def feature_type
        params[:type] || "SequenceFeature"
    end

    def chrom_label(chrom)
        "#{ chrom.primaryIdentifier }:#{(params[:start] || 0).to_i + 1}..#{params[:end] || chrom.length}"
    end

    def get_refseq_feature(label, name, segment = {})
        seq = adaptor(label).sequence(name, "Chromosome", segment)
        [ InterMine::JBrowse::ReferenceSequence.create(segment, seq) ]
    end

    def get_features(label, name, segment = {})
        if segment[:sequence] and segment[:type] == "Chromosome"
            return get_refseq_feature(label, name, segment)
        end

        fs = adaptor(label).features(name, "Chromosome", feature_type, segment)
        fs.map {|f| InterMine::JBrowse::Feature.create(f) }
    end

    # Routes to manage services

    get "/services", :provides => [:html, :json] do
        respond_with :services, settings.services
    end

    get "/services/:name", :provides => [:html, :json] do |name|
        respond_to do |f|
            f.json do
                service = settings.services[name] or halt 404
                service.to_json
            end
            f.html do
                haml :index, :locals => {
                    :global_stats => adaptor(name).global_stats,
                    :ref_seqs => adaptor(name).refseqs
                }
            end
        end
    end

    get "/services/:name/:refseq", :provides => [:html, :json] do |name, refseq|
        child_type = params[:type] || "SequenceFeature"
        mine = adaptor(name)
        respond_with :refseq, {
            :refseq => mine.feature(refseq, "Chromosome"),
            :stats => mine.stats(refseq, "Chromosome", child_type, params)
        }
    end

    get "/services/:name/:refseq/features", :provides => [:html, :json] do |name, refseq|
        child_type = params[:type] || "SequenceFeature"
        mine = adaptor(name)
        respond_with :features, {
            :refseq => mine.feature(refseq, "Chromosome"),
            :features => get_features(name, refseq, params)
        }
    end

    get "/services/:name/:refseq/residues", :provides => [:html, :json] do |name, refseq|
        mine = adaptor(name)
        respond_with :sequence, {
            :sequence => mine.sequence(refseq, "Chromosome", params)
        }
    end

    post "/services", :provides => [:json, :html] do
        unless params[:root] and params[:taxon] and params[:label]
            error 400
        end
        lebel = params[:label]
        service = params.select { |k, v| [:root, :taxon, :label].include? k }
        adaptor = InterMine::JBrowse::Adaptor.new(service)

        ADAPTORS[label] = adaptor
        settings.services[label] = service

        respond_to do |f| 
            f.json { service.to_json }
            f.html { redirect to("/services/#{ label }"), 201}
        end
    end

    # Routes to run a local JBrowse.

    get %r{/JBrowse-.*/data/names/root.json} do
        {}.to_json
    end

    get "/:service/jbrowse/jbrowse_conf.json", :provides => [:json] do |label|
        dataset = {:url => "#{ request.base_url }/#{ label }", :name => "#{ label} data"}
        datasets = Hash.new()
        datasets.store(label, dataset)
        respond_with :datasets => datasets
    end

    get "/:service/jbrowse/data/trackList.json", :provides => [:json] do |label|
        tracks = adaptor(label).sequence_types.map do |c|
            {
                :label => "#{label}_#{ c.name }_track",
                :key => "#{ c.name }s",
                :type => "JBrowse/View/Track/HTMLFeatures",
                :storeClass => "JBrowse/Store/SeqFeature/REST",
                :baseUrl => "#{ request.base_url }/#{ label }",
                :query => { :type => c.name }
            }
        end

        tracks << {
            :label => "#{ label }_sequence_track",
            :key => "DNA",
            :type => "JBrowse/View/Track/Sequence",
            :storeClass => "JBrowse/Store/SeqFeature/REST",
            :baseUrl => "#{ request.base_url }/#{ label }",
            :query => { :sequence => true, :type => "Chromosome" }
        }

        respond_with :dataset_id => "InterMine", :tracks => tracks

    end

    get "/:service/jbrowse/data/seq/refSeqs.json", :provides => [:json] do |label|
        data = adaptor(label).refseqs.map do |rs|
            {:name => rs.primaryIdentifier, :start => 0, :end => rs.length }
        end
        respond_with data
    end

    # And here begin the routes required by the JBrowse REST Store API

    get "/jbrowse/:service/stats/global", :provides => [:json] do |label|
        adaptor(label).global_stats.to_json
    end

    get "/jbrowse/:service/stats/region/:refseq_name", :provides => [:json] do |label, name|
        adaptor(label).stats(name, "Chromosome", feature_type, params).to_json
    end

    get "/jbrowse/:service/features/:refseq_name", :provides => [:json] do |label, name|
        {:features => get_features(label, name, params)}.to_json
    end

    # The routes useful for graphical inspection of the app.

    get "/" do
        redirect to("/services")
    end

    run! if app_file == $0

end

