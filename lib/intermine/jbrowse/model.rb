module InterMine
    module JBrowse

        module Hashlike

            def to_json(*a)
                self.to_h.to_json(*a)
            end

            def to_h
                Hash[ each_pair.to_a ]
            end

        end

        BasicFeature = Struct.new("BasicFeature", :type, :name, :uniqueID, :start, :end, :strand) do 

            include Hashlike

            def self.create(locatedFeature)
                feature = locatedFeature.feature
                type = feature.sequenceOntologyTerm.name
                name = feature.name or feature.symbol
                uniqueID = feature.primaryIdentifier
                BasicFeature.new(type, name, uniqueID, locatedFeature.start, locatedFeature.end, locatedFeature.strand)
            end
        end

        ReferenceSequence = Struct.new("ReferenceSequence", :start, :end, :seq) do

            include Hashlike

            def self.create(segment, seq)
                ReferenceSequence.new((segment[:start] || 0), segment[:end], seq)
            end
        end

        Feature = Struct.new("Feature", :type, :name, :uniqueID, :start, :end, :strand, :subfeatures) do

            include Hashlike

            def self.create(locatedFeature)
                parsed = BasicFeature.create(locatedFeature).values

                feature = locatedFeature.feature
                if feature.nil?
                    raise "This location has no feature! #{ locatedFeature }"
                end
                child_features = feature.locatedFeatures
                if child_features.nil?
                    subfeatures = []
                else
                    subfeatures = child_features.map {|sf| BasicFeature.create(sf)}
                end
                values = parsed + [subfeatures]
                Feature.new(*values)
            end

            def to_h
                Hash[ each_pair.map{ |k, v| [k, (k == :subfeatures) ? v.map(&:to_h) : v]}]
            end

        end
    end
end
