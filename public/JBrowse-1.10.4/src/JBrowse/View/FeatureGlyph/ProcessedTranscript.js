define("JBrowse/View/FeatureGlyph/ProcessedTranscript", [
           'dojo/_base/declare',
           'dojo/_base/array',
           'dojox/color/Palette',
           'JBrowse/View/FeatureGlyph/Segments'
       ],
       function(
           declare,
           array,
           Palette,
           SegmentsGlyph
       ) {

return declare( SegmentsGlyph, {

_defaultConfig: function() {
    return this._mergeConfigs(
        this.inherited(arguments),
        {
            style: {
                utrColor: function( feature, variable, glyph, track ) {
                    return glyph._utrColor( glyph.getStyle( feature.parent(), 'color' ) ).toString();
                }
            },
            subParts: 'CDS, UTR, five_prime_UTR, three_prime_UTR'
        });
},

_utrColor: function( baseColor ) {
    return (this._palette || (this._palette = Palette.generate( baseColor, "splitComplementary"))).colors[1];
},

_isUTR: function( feature ) {
    return /(\bUTR|_UTR|untranslated[_\s]region)\b/.test( feature.get('type') || '' );
},

getStyle: function( feature, name ) {
    if( name == 'color' ) {
        if( this._isUTR( feature ) )
            return this.getStyle( feature, 'utrColor' );
    }

    return this.inherited(arguments);
},

_getFeatureHeight: function( viewInfo, feature ) {
    var height = this.inherited( arguments );

    if( this._isUTR( feature ) )
        return height*0.65;

    return height;
}

});
});
