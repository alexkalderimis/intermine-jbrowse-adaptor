require "rubygems"

require "intermine/service"

module InterMine
    module JBrowse
        class Adaptor

            EMPTY_SUMMARY = Hash.new

            attr_reader :taxId

            attr_accessor :page_size

            def initialize(opts)
                @sequence_cache = {}
                @feature_counts = {}
                @stats_cache = {}
                @page_size = 1000 # basepairs
                @refseqs = nil
                @service = Service.new(opts["root"])
                @taxId = opts[:taxon]
            end

            def root
                @service.root
            end

            def api_version
                @service.version
            end

            def short_segment(name, segment = {})
                x = (segment[:start] || 0).to_i
                y = (segment[:end] || feature(name, "Chromosome").length).to_i
                if y - x > page_size
                    y = x + page_size
                end
                {:start => x, :end => y}
            end

            def sequence_types
                sf = @service.model.table("SequenceFeature")
                @service.model.classes.values.select do |c|
                    c.name != "Chromosome" and c.subclass_of? sf
                end
            end

            def refseqs
                if @refseqs.nil?
                    @refseqs = chromosomes.select(:primaryIdentifier, :length, "organism.shortName").where(:length => {:gt => 0}).all.to_a
                else
                    @refseqs
                end
            end

            def count_features(type = "SequenceFeature")
                if @feature_counts[type].nil?
                    @feature_counts[type] = @service.query(type).select(:id).where(for_organism).count
                else
                    @feature_counts[type]
                end
            end

            def global_stats
                serve_from_cache @stats_cache, "#{ @service.release }/global" do
                    feature_count = count_features
                    total_length = refseqs.map(&:length).compact.reduce(&:+)
                    density = feature_count.to_f / total_length.to_f
                    score_summary = @service.query("SequenceFeature").summaries(:score).first
                    {
                        :featureCount => feature_count,
                        :featureDensity => density,
                        :scoreMin => score_summary["min"],
                        :scoreMax => score_summary["max"],
                        :scoreMean => score_summary["average"],
                        :scoreStdDev => score_summary["stdev"]
                    }
                end
            end

            def feature(name, type = "SequenceFeature", segment = {})
                q = @service.query(type).select("*").where(for_organism_and_name(name))
                if segment[:sequence]
                    q.add_to_select("sequence.residues")
                end
                q.first
            end

            def sequence(name, type = "SequenceFeature", segment = {})
                if @service.version < 14
                    do_seq_with_cache name, type, segment
                else
                    do_native_sequence name, type, segment
                end
            end

            def stats(name, type = "Chromosome", ftype = "SequenceFeature", segment = {})
                key = "#{ @service.release }/#{ name }/#{ type }/#{ ftype }/#{ segment[:start] }..#{segment[:end]}"
                serve_from_cache @stats_cache, key do
                    q = @service.query(ftype).select(:id).where(for_organism)
                    seq_feat = feature(name, type, segment)
                    range = get_range name, segment
                    length = segment_length name, type, segment

                    unless range.nil?
                        if segment[:start] == 0 and segment[:end] == seq_feat.length
                            q = q.where("chromosomeLocation.locatedOn.primaryIdentifier" => name)
                        else
                            q = q.where(:chromosomeLocation => {:OVERLAPS => [range]})
                        end
                    end

                    score_summary = (q.summaries(:score).first || EMPTY_SUMMARY)
                    c = q.count

                    density = c.to_f / length.to_f

                    {
                        :featureCount => c, :featureDensity => density,
                        :scoreMin => score_summary["min"],
                        :scoreMax => score_summary["max"],
                        :scoreMean => score_summary["average"],
                        :scoreStdDev => score_summary["stdev"]
                    }
                end
            end

            def features(on, parent_type = "Chromosome", feature_type = "SequenceFeature", segment = {})
                q = located_features_q on, parent_type, feature_type

                if segment[:subfeatures]
                    q = add_subfeatures(q)
                end

                range = get_range on, segment

                unless range.nil?
                    q = q.where(:locatedFeatures => {:OVERLAPS => [range]})
                end

                chrom = q.first

                if chrom.nil?
                    puts "No chromosome found"
                    return []
                else
                    chrom.locatedFeatures
                end

            end

            private

            def do_seq_with_cache(name, type, segment)
                dna = serve_from_cache @sequence_cache, "#{ type }/#{ name }" do
                    feature(name, type, {:sequence => true}).sequence.residues
                end
                    
                s = segment[:start] || 0
                e = segment[:end] || dna.size
                len = e.to_i - s.to_i
                dna[s.to_i, len]
            end

            def do_native_sequence(name, type, segment)
                result = @service.query(type).
                    select("sequence.residues").
                    where(for_organism_and_name(name)).
                    sequences(segment).
                    first
                result["seq"]
            end

            def from_interbase(segment)
                {
                    :start => ((segment[:start] or 0).to_i + 1),
                    :end => segment[:end]
                }
            end

            def for_organism
                {"organism.taxonId" => @taxId}
            end

            def for_organism_and_name(name)
                for_organism.merge(:primaryIdentifier => name)
            end

            def chromosomes
                @service.query("Chromosome").where(for_organism)
            end

            def add_subfeatures(q)
                type_constraint = {
                    "locatedFeatures.feature.locatedFeatures.feature" => {
                        :sub_class => "SequenceFeature"
                     }
                }

                q.where(type_constraint).add_to_select(*sub_feature_view)
            end

            def sub_feature_view
                [
                    "locatedFeatures.feature.locatedFeatures.*",
                    "locatedFeatures.feature.locatedFeatures.feature.*",
                    "locatedFeatures.feature.locatedFeatures.feature.sequenceOntologyTerm.name"
                ]
            end

            def located_features_q(name, parent = "Chromosome", child = "SequenceFeature")
                view = feature_view
                if @service.model.table(child).has_field? "description"
                    view << "locatedFeatures.feature.description"
                end
                @service.query(parent).
                    where("locatedFeatures.feature" => {:sub_class => child}).
                    select(*view).
                    where(for_organism_and_name(name)).
                    outerjoin("locatedFeatures").
                    outerjoin("locatedFeatures.feature.sequenceOntologyTerm")
            end

            def feature_view
                [
                    "primaryIdentifier",
                    "locatedFeatures.*",
                    "locatedFeatures.feature.*",
                    "locatedFeatures.feature.score",
                    "locatedFeatures.feature.sequenceOntologyTerm.name"
                ]
            end

            def segment_length(name, type, segment = {})
                if segment[:start].nil? and segment[:end].nil?
                    return feature(name, type).length
                elsif segment[:start].nil? or segment[:end].nil?
                    if segment[:start].nil?
                        return segment[:end].to_i
                    else
                        return feature(name, type).length - segment[:start].to_i
                    end
                else
                    return segment[:end].to_i - segment[:start].to_i
                end
            end

            def get_range(name, segment = {})
                if segment.nil?
                    return nil
                elsif segment[:start].nil? and segment[:end].nil?
                    return nil
                elsif segment[:start].nil? or segment[:end].nil?
                    return "#{name}:#{segment[:start] or segment[:end]}"
                else
                    pos = from_interbase segment
                    return "#{name}:#{pos[:start]}..#{pos[:end]}"
                end
            end

            def serve_from_cache(cache, key)
                if cache[key].nil?
                    cache[key] = yield
                end
                return cache[key]
            end

        end
    end
end
