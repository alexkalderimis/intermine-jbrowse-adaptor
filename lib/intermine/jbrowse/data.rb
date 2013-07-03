require "rubygems"

require "intermine/service"

module InterMine
    module JBrowse
        class Adaptor

            def initialize(url, taxId)
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
                chromosomes.select(:primaryIdentifier, :length).all
            end

            def count_features(type = "SequenceFeature")
                @service.query(type).select(:id).where(for_organism).count
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

        end
    end
end
