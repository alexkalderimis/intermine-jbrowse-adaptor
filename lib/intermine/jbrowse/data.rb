require "rubygems"

require "intermine/service"

module InterMine
    module JBrowse
        class Adaptor

            def initialize(url, taxId)
                @sequence_cache = {}
                @feature_counts = {}
                @refseqs = nil
                @service = Service.new(url)
                @taxId = taxId
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

            def refseqs
                if @refseqs.nil?
                    @refseqs = chromosomes.select(:primaryIdentifier, :length).all.to_a
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
                feature_count = count_features
                total_length = refseqs.map(&:length).compact.reduce(&:+)
                density = feature_count.to_f / total_length.to_f
                {:featureCount => feature_count, :featureDensity => density}
            end

            def feature(name, segment = {}, type = "SequenceFeature")
                q = @service.query(type).select("*").where(for_organism_and_name(name))
                if segment[:sequence]
                    q.add_to_select("sequence.residues")
                end
                q.first
            end

            def sequence(name, type = "SequenceFeature", segment = {})
                key = "#{ type }/#{ name }"
                cache = @sequence_cache
                unless cache.has_key? key
                    cache[key] = feature(name, {:sequence => true}, type).sequence.residues
                end
                    
                dna = @sequence_cache[key]
                s = segment[:start] || 0
                e = segment[:end] || dna.size
                len = e.to_i - s.to_i
                dna[s.to_i, len]
            end

            def stats(name, type = "Chromosome", feature = "SequenceFeature", segment = {})
                q = @service.query(feature).select(:id).where(for_organism)
                range = get_range name, segment
                length = segment_length name, type, segment

                unless range.nil?
                    q = q.where(:chromosomeLocation => {:OVERLAPS => [range]})
                end

                c = q.count
                density = c.to_f / length.to_f
                {:featureCount => c, :featureDensity => density}
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
                @service.query(parent).
                    where("locatedFeatures.feature" => {:sub_class => child}).
                    select(*feature_view).
                    where(for_organism_and_name(name)).
                    outerjoin("locatedFeatures")
            end

            def feature_view
                [
                    "primaryIdentifier",
                    "locatedFeatures.*",
                    "locatedFeatures.feature.*",
                    "locatedFeatures.feature.sequenceOntologyTerm.name"
                ]
            end

            def segment_length(name, type, segment = {})
                if segment[:start].nil? and segment[:end].nil?
                    return feature(name, {}, type).length
                elsif segment[:start].nil? or segment[:end].nil?
                    if segment[:start].nil?
                        return segment[:end].to_i
                    else
                        return feature(name, {}, type).length - segment[:start].to_i
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
                    return "#{name}:#{segment[:start]}..#{segment[:end]}"
                end
            end

        end
    end
end
