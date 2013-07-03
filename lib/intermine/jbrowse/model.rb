module InterMine
    module JBrowse

        module Hashlike

            attr_accessor @@fields

            def to_json(*a)
                self.to_h.to_json(*a)
            end

            def to_h
                Hash[ instance_variables.map {|ivar| [f, send(f)]} ]
            end

        end

        class BasicFeature

            @@fields = [:type, :name, :uniqueID, :start, :end, :strand]

            include Hashlike

            def initialize(locatedFeature)
                feature = locatedFeature.feature
                @type = feature.sequenceOntologyTerm.name
                @name = feature.name or feature.symbol
                @uniqueID = feature.primaryIdentifier
                @start = locatedFeature.start
                @end = locatedFeature.end
                @strand = locatedFeature.strand
            end

        end

        class ReferenceSequence

            @@fields = [:start, :end, :seq]

            include Hashlike

            def initialize(segment, seq)
                @seq = seq
                @start = segment[:start] or 0
                @end = segment[:end]
            end

        end

        class Feature < BasicFeature

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
                    @subfeatures = child_features.map {|sf| BasicFeature.new(sf)}
                end
            end

            def to_h
                super.merge({:subfeatures => @subfeatures.map(&:to_h)})
            end
        end
    end
end
