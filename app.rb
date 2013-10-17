require "rubygems"

require "intermine/service"
require "sinatra/base"
require "sinatra/config_file"
require "sinatra/respond_with"
require "sinatra/cross_origin"
require "haml"
require "json"
require "multi_json"

require "./lib/intermine/jbrowse/data"
require "./lib/intermine/jbrowse/model"

class JBrowsify < Sinatra::Base

    register Sinatra::ConfigFile
    register Sinatra::RespondWith
    register Sinatra::CrossOrigin

    config_file "config.yml"

    ADAPTORS = Hash.new

    configure :development do
        enable :logging
    end
    
    before do
        if JBrowsify::ADAPTORS.empty?
            settings.services.each do |n, opts|
                h = Hash.new
                s = Service.new(opts["root"])
                s.select("Organism.taxonId").results.each do |org|
                    logger.info "New adaptor for #{ n }: #{ org.taxonId }"
                    h[org.taxonId.to_s] = InterMine::JBrowse::Adaptor.new(opts.merge :taxon => org.taxonId)
                end
                JBrowsify::ADAPTORS[n] = h
            end
        end
    end

    # Common control methods shared by HTML and JSON outputs

    def organisms(name)
        opts = settings.services[name] or halt 404
        s = Service.new opts["root"]
        s.select("Organism.*").all
    end

    def adaptor(name)
        org = ( params[:taxon] || settings.services[name]["defaultTaxon"].to_s )
        a = begin
            ADAPTORS[name][org]
        rescue
            nil
        end
        a or error 404
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

    def jbrowse_base(service, taxonId)
        adaptor = adaptor(service)
        if adaptor.api_version >= 15
            [adaptor(service).root, :jbrowse, taxonId, ''].join '/'
        else
            [request.base_url, :jbrowse, service, ''].join '/'
        end
    end

    def get_refseq_feature(label, name, segment = {})
        seq = adaptor(label).sequence(name, "Chromosome", segment)
        [ InterMine::JBrowse::ReferenceSequence.create(segment, seq, name) ]
    end

    def get_features(label, name, segment = {})
        if segment[:sequence] and segment[:type] == "Chromosome"
            return get_refseq_feature(label, name, segment)
        end
        service = adaptor(label)
        link_base = service.root.sub(/service\/?$/, '')

        fs = service.features(name, "Chromosome", feature_type, segment)
        fs.map {|f| InterMine::JBrowse::Feature.create(f, link_base)}
    end

    # Routes to manage services

    get "/services", :provides => [:html, :json] do
        respond_with :services, settings.services
    end

    get "/services/:name/:taxon", :provides => [:html, :json] do |name, taxon|
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
        label = params[:label]
        service = params.select { |k, v| [:root, :taxon, :label].include? k }
        adaptor = InterMine::JBrowse::Adaptor.new(service)

        ADAPTORS[label] = adaptor
        settings.services[label] = service

        respond_to do |f| 
            f.json { service.to_json }
            f.html { redirect to("/services/#{ label }"), 201}
        end
    end

    # And here begin the routes required by the JBrowse REST Store API

    get "/jbrowse/:service/stats/global", :provides => [:json] do |label|
        cross_origin
        adaptor(label).global_stats.to_json
    end

    get "/jbrowse/:service/stats/region/:refseq_name", :provides => [:json] do |label, name|
        cross_origin
        adaptor(label).stats(name, "Chromosome", feature_type, params).to_json
    end

    get "/jbrowse/:service/features/:refseq_name", :provides => [:json] do |label, name|
        cross_origin
        {:features => get_features(label, name, params)}.to_json
    end

    # Routes to run a local JBrowse.

    get "/jbrowse/:service/:taxon/data/names/root.json" do
        "{}"
    end

    get "/jbrowse/:service/:taxon/InterMine/Store/SeqFeature/WS.js" do
        send_file [settings.public_folder, :javascript, "intermine-store.js"].join('/')
    end

    get "/jbrowse/:service/:taxon/jbrowse_conf.json", :provides => [:json] do |label, taxonId|
        cross_origin
        dataset = {
            :url => jbrowse_base(label, taxonId),
            :name => "#{ label } data"
        }
        datasets = Hash.new()
        datasets.store(label, dataset)
        respond_with :datasets => datasets, :exactReferenceSequenceNames => true
    end

    get "/jbrowse/:service/:taxon/data/trackList.json", :provides => [:json] do |label, taxonId|
        cross_origin
        base = jbrowse_base(label, taxonId)
        tracks = []
        store = {
            :type => "JBrowse/Store/SeqFeature/REST",
            :baseUrl => base,
            :region_feature_densities => true,
            :region_stats => true
        }
        stores = Hash.new
        stores.store(label, store)

        adaptor(label).sequence_types.each do |c|
            tracks << {
                :label => "#{label}_#{ c.name }_track",
                :key => "#{ c.name }s in #{ label }",
                :type => "JBrowse/View/Track/HTMLFeatures",
                :storeClass => "JBrowse/Store/SeqFeature/REST",
                :baseUrl => base,
                :region_feature_densities => true,
                :regionFeatureDensities => true,
                :region_stats => true,
                :query => { :type => c.name, :taxon => taxonId}
            }
        end

        tracks << {
            :label => "#{ label }_sequence_track",
            :key => "DNA",
            :type => "JBrowse/View/Track/Sequence",
            :storeClass => "JBrowse/Store/SeqFeature/REST",
            :baseUrl => base,
            :query => {
                :sequence => true,
                :reference => true,
                :type => "Chromosome",
                :taxon => taxonId
            }
        }

        respond_with :stores => stores, :refSeqSelectorMaxSize => tracks.size, :dataset_id => "InterMine", :tracks => tracks.sort {|a, b| a[:label] <=> b[:label] }

    end

    get "/jbrowse/:service/:taxon/data/seq/refSeqs.json", :provides => [:json] do |label, taxonId|
        cross_origin
        datasets = adaptor(label).refseqs.map do |rs|
            {
                :name  => rs.primaryIdentifier,
                :start => 0,
                :end   => rs.length
            }
        end.to_a
        respond_with datasets
    end

    get "/jbrowse/:service" do |name|
        taxonId = (settings.services[name]["defaultTaxon"] or error 404)
        redirect to("/jbrowse/#{ name }/#{ taxonId }/index.html")
    end

    get "/jbrowse/:service/:taxon" do |name, taxonId|
        redirect to("/jbrowse/#{ name }/#{ taxonId }/index.html")
    end

    get %r{/jbrowse/(\w+)/(\w+)/(.+)} do |name, taxon, path|
        root = File.dirname(__FILE__)
        file = File.join(root, settings.public_folder, settings.jbrowse_dir, path)
        if File.exist? file
            send_file(file)
        else
            pass
        end
    end

    # The routes useful for graphical inspection of the app.

    get "/" do
        redirect to("/services")
    end

    run! if app_file == $0

end

