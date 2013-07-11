/**
 * Store class that speaks to InterMine webservices.
 */

(function(define) {
  var dependencies = [
    'dojo/_base/declare',
    'dojo/_base/array',
    'dojo/request/xhr',
    'JBrowse/Store/SeqFeature',
    'JBrowse/Model/SimpleFeature'
  ];

  define(dependencies, function(declare, array, xhr, SeqFeatureStore, SimpleFeature) {
    return declare(SeqFeatureStore, {

      constructor: function(config) {
        this.config = config;
      },

      getGlobalStats: function(onSucc, onErr) {
      },

      getRegionStats: function(query, onSucc, onErr) {
        console.log("Region query", query);
      },

      getFeatures: function(query, gotFeature, done, error) {
      }

    });
  });
}).call(this, define);

