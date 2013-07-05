require "rubygems"

require "intermine/service"
require "sinatra/base"
require "sinatra/config_file"
require "sinatra/respond_with"
require "haml"
require "json"

require "./lib/intermine/jbrowse/data"
require "./lib/intermine/jbrowse/model"

class JBrowsify < Sinatra::Base

    register Sinatra::ConfigFile
    register Sinatra::RespondWith

    ADAPTORS = Hash[ settings.services.map{ |n, s| [n, InterMine::JBrowse::Adaptor.new(s)] } ]

    def adaptor(name)
        ADAPTORS[name] or halt 404
    end

    # Common control methods shared by HTML and JSON outputs

    def feature_type
        params[:type] || "SequenceFeature"
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

    post "/services", :provides => [:json, :html] do
        unless params[:root] and params[:taxon] and params[:label]
            error 400
        end
        service = params.select { |k, v| [:root, :taxon].include? k }
        adaptor = InterMine::JBrowse::Adaptor.new(service)

        ADAPTORS[params[:label]] = adaptor
        settings.services[params[:label]] = service

        respond_to do |f| 
            f.json { service.to_json }
            f.html { redirect to("/services/#{ params[:label] }"), 201
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

    get "/:service/stats/global", :provides => [:json] do |label|
        adaptor(label).global_stats.to_json
    end

    get "/:service/stats/region/:refseq_name", :provides => [:json] do |label, name|
        adaptor(label).stats(name, "Chromosome", feature_type, params).to_json
    end

    get "/:service/features/:refseq_name", :provides => [:json] do |label, name|
        {:features => get_features(label, name, params)}.to_json
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
            :short_seg => short_segment(name, params),
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

    run! if app_file == $0

end

