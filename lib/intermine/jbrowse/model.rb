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

        BasicFeature = Struct.new("BasicFeature", :type, :name, :description, :symbol, :score, :uniqueID, :start, :end, :strand, :link) do 

            include Hashlike

            def self.create(locatedFeature, link_base = '')
                feature = locatedFeature.feature
                type = feature.sequenceOntologyTerm ? feature.sequenceOntologyTerm.name : feature.instance_variable_get('@__cd__').name
                name = (feature.name or feature.symbol or feature.primaryIdentifier)
                symbol = feature.symbol
                description = feature.respond_to?(:description) ? feature.description : nil
                score = feature.score
                uniqueID = feature.primaryIdentifier
                href = "#{ link_base }report.do?id=#{ feature.objectId }"
                link = "<a href=\"#{ href }\">#{ href }</a>"
                BasicFeature.new(type, name, description, symbol, score, uniqueID, locatedFeature.start, locatedFeature.end, locatedFeature.strand, link)
            end
        end

        ReferenceSequence = Struct.new("ReferenceSequence", :start, :end, :seq) do

            include Hashlike

            def self.create(segment, seq)
                ReferenceSequence.new((segment[:start] || 0), segment[:end], seq)
            end
        end

        Feature = Struct.new("Feature", :type, :name, :description, :symbol, :score, :uniqueID, :start, :end, :strand, :link, :subfeatures) do

            include Hashlike

            def self.create(locatedFeature, link_base = '')
                values = BasicFeature.create(locatedFeature, link_base).values

                feature = locatedFeature.feature
                if feature.nil?
                    raise "This location has no feature! #{ locatedFeature }"
                end
                cfs = feature.locatedFeatures
                values << (cfs.nil? ? [] : cfs.map {|sf| BasicFeature.create(sf)})
                Feature.new(*values)
            end

            def to_h
                Hash[ each_pair.map{ |k, v| [k, (k == :subfeatures) ? v.map(&:to_h) : v]}]
            end

        end
    end
end
