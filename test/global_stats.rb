require "test/unit"
require "set"
require "../lib/intermine/jbrowse/data"

BASES = Set['g', 't', 'c', 'a']

class TestJBrowseAdaptor < Test::Unit::TestCase

    def setup
        @adaptor = InterMine::JBrowse::Adaptor.new("www.flymine.org/query", 7227)
    end

    def teardown
        ## No action required
    end

    def test_get_reference_sequences
        refseqs = @adaptor.refseqs
        assert(refseqs.count > 10, "There are at least 10 reference sequences")
    end

    def test_refseqs_include_X
        refseqs = @adaptor.refseqs
        assert(refseqs.detect {|rs| rs.primaryIdentifier == 'X'}, "And X is one of them")
    end

    def test_refseqs_have_fields
        refseqs = @adaptor.refseqs
        assert(refseqs.all? {|rs| rs.primaryIdentifier },
            "#{ refseqs.detect {|rs| not rs.primaryIdentifier } } doesn't have the right fields")
    end

    def test_count_features
        c = @adaptor.count_features
        assert(c > 200_000, "There are too few features")
    end

    def test_count_different_feature_types
        g = @adaptor.count_features "Gene"
        e = @adaptor.count_features "Exon"
        assert(e > g, "There are more genes (#{ g }) than exons (#{ e })")
    end

    def test_global_stats
        stats = @adaptor.global_stats
        assert(stats[:featureCount] > 200_000, "There are too few features")
        assert_in_delta(0.015, stats[:featureDensity], 0.005, "#{ stats[:featureDensity] } is odd")
    end

    def test_feature
        x_chrom = @adaptor.feature("X", {}, "Chromosome")
        assert(x_chrom.length > 200_000, "X is suitably long")
    end

    def test_seq
        dna = @adaptor.sequence("FBgn0004053", "Gene")
        assert dna.chars.all? {|c| BASES.include? c}
    end

    def test_sub_seq
        zen = @adaptor.feature("FBgn0004053", {}, "Gene")
        all_dna = @adaptor.sequence("FBgn0004053", "Gene")
        some_dna = @adaptor.sequence("FBgn0004053", "Gene", {:end => zen.length / 2})

        assert(all_dna.size > some_dna.size, "All dna #{ all_dna.size } isn't bigger than some dna #{ some_dna.size }")
        assert(all_dna.include?(some_dna), "All dna doesn't contain some dna")
    end

    def test_feature_stats
        stats = @adaptor.stats("X")
        assert(stats[:featureCount] > 100_000, "Too few features")
        assert_in_delta(0.09, stats[:featureDensity], 0.005, "Density is off")
    end

end

