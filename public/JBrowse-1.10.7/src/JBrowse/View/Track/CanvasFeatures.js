//>>built
define("JBrowse/View/Track/CanvasFeatures","dojo/_base/declare,dojo/_base/array,dojo/_base/lang,dojo/_base/event,dojo/mouse,dojo/dom-construct,dojo/Deferred,dojo/on,JBrowse/has,JBrowse/View/GranularRectLayout,JBrowse/View/Track/BlockBased,JBrowse/View/Track/_ExportMixin,JBrowse/Errors,JBrowse/View/Track/_FeatureDetailMixin,JBrowse/View/Track/_FeatureContextMenusMixin,JBrowse/Model/Location".split(","),function(l,g,q,i,A,j,r,k,s,t,u,v,B,w,x,y){var z=l(null,{constructor:function(a){this.dims={h:a.h,
w:a.w};this.byID={}},getByID:function(a){return this.byID[a]},addAll:function(a){var b=this.byID;g.forEach(a,function(a){a&&(b[a.f.id()]=a)},this)},getAll:function(){var a=[],b;for(b in this.byID)a.push(this.byID[b]);return a}});return l([u,w,v,x],{constructor:function(){this.glyphsLoaded={};this.glyphsBeingLoaded={};this.regionStats={};this.showLabels=this.config.style.showLabels;this.showTooltips=this.config.style.showTooltips;this.displayMode=this.config.displayMode;this._setupEventHandlers()},
_defaultConfig:function(){return{maxFeatureScreenDensity:400,glyph:q.hitch(this,"guessGlyphType"),maxFeatureGlyphExpansion:500,maxHeight:600,style:{_defaultHistScale:4,_defaultLabelScale:30,_defaultDescriptionScale:120,showLabels:!0,showTooltips:!0},displayMode:"normal",events:{contextmenu:function(a,b,c,d,e){e=i.fix(e);b&&b.contextMenu&&b.contextMenu._openMyself({target:c.featureCanvas,coords:{x:e.pageX,y:e.pageY}});i.stop(e)}},menuTemplate:[{label:"View details",title:"{type} {name}",action:"contentDialog",
iconClass:"dijitIconTask",content:dojo.hitch(this,"defaultFeatureDetail")},{label:function(){return"Highlight this "+(this.feature&&this.feature.get("type")?this.feature.get("type"):"feature")},action:function(){this.track.browser.setHighlightAndRedraw(new y({feature:this.feature,tracks:[this.track]}))},iconClass:"dijitIconFilter"}]}},setViewInfo:function(a,b,c,d,e,f,h){this.inherited(arguments);this.staticCanvas=j.create("canvas",{style:{height:"100%",cursor:"default",position:"absolute",zIndex:15}},
d);this.staticCanvas.height=this.staticCanvas.offsetHeight;this._makeLabelTooltip()},guessGlyphType:function(a){return"JBrowse/View/FeatureGlyph/"+({gene:"Gene",mRNA:"ProcessedTranscript"}[a.get("type")]||"Box")},fillBlock:function(a){var b=a.blockIndex,c=a.block,d=a.scale;s("canvas")?this.store.getGlobalStats(dojo.hitch(this,function(e){e=dojo.mixin({stats:e,displayMode:this.displayMode,showFeatures:d>=(this.config.style.featureScale||(e.featureDensity||0)/this.config.maxFeatureScreenDensity),showLabels:this.showLabels&&
"normal"==this.displayMode&&d>=(this.config.style.labelScale||(e.featureDensity||0)*this.config.style._defaultLabelScale),showDescriptions:this.showLabels&&"normal"==this.displayMode&&d>=(this.config.style.descriptionScale||(e.featureDensity||0)*this.config.style._defaultDescriptionScale)},a);e.showFeatures?this.fillFeatures(dojo.mixin(e,a)):(this.fillTooManyFeaturesMessage(b,c,d),a.finishCallback())}),dojo.hitch(this,function(b){this._handleError(b,a);a.finishCallback(b)})):(this.fatalError="This browser does not support HTML canvas elements.",
this.fillBlockError(b,c,this.fatalError))},_getLayout:function(a){if(!this.layout||this._layoutpitchX!=4/a){var b=this.getConf("layoutPitchY")||4;this.layout=new t({pitchX:4/a,pitchY:b,maxHeight:this.getConf("maxHeight"),displayMode:this.displayMode});this._layoutpitchX=4/a}return this.layout},_clearLayout:function(){delete this.layout},hideAll:function(){this._clearLayout();return this.inherited(arguments)},getGlyph:function(a,b,c){var d=this.getConfForFeature("glyph",b),e;if(e=this.glyphsLoaded[d])c(e);
else if(a=this.glyphsBeingLoaded[d])a.push(c);else{var f=this;this.glyphsBeingLoaded[d]=[c];require([d],function(a){e=f.glyphsLoaded[d]=new a({track:f,config:f.config,browser:f.browser});g.forEach(f.glyphsBeingLoaded[d],function(a){a(e)});delete f.glyphsBeingLoaded[d]})}},fillFeatures:function(a){var b=this,c=a.blockIndex,d=a.block,e=d.domNode.offsetWidth,f=a.scale,h=a.leftBase,m=a.rightBase,o=a.finishCallback,n=[],g=0,i=new r,k=!1,l=dojo.hitch(b,function(b){this._handleError(b,a);o(b)}),p=this._getLayout(f),
f=Math.round(this.config.maxFeatureGlyphExpansion/f);this.store.getFeatures({ref:this.refSeq.name,start:Math.max(0,h-f),end:m+f},function(c){if(!b.destroyed&&b.filterFeature(c)){n.push(null);g++;var f=n.length-1;b.getGlyph(a,c,function(b){b=b.layoutFeature(a,p,c);null===b?d.maxHeightExceeded=!0:b.l>=e||0>b.l+b.w||(n[f]=b);!--g&&k&&i.resolve()},l)}},function(){b.destroyed||(k=!0,!g&&!i.isFulfilled()&&i.resolve(),i.then(function(){var e=p.getTotalHeight();d.featureCanvas=j.create("canvas",{height:e,
width:d.domNode.offsetWidth+1,style:{cursor:"default",height:e+"px",position:"absolute"},innerHTML:"Your web browser cannot display this type of track.",className:"canvas-track"},d.domNode);d.maxHeightExceeded&&b.markBlockHeightOverflow(d);b.heightUpdate(e,c);b.renderFeatures(a,n);b.renderClickMap(a,n);o()}))},l)},startZoom:function(){this.inherited(arguments);g.forEach(this.blocks,function(a){try{a.featureCanvas.style.width="100%"}catch(b){}})},endZoom:function(){g.forEach(this.blocks,function(a){try{delete a.featureCanvas.style.width}catch(b){}});
this.clear();this.inherited(arguments)},renderClickMap:function(a,b){var c=a.block,d=new z({h:c.featureCanvas.height,w:c.featureCanvas.width});c.fRectIndex=d;d.addAll(b);!c.featureCanvas||!c.featureCanvas.getContext("2d")?console.warn("No 2d context available from canvas"):(this._attachMouseOverEvents(),this._connectEventHandlers(c),this.updateStaticElements({x:this.browser.view.getX()}))},_attachMouseOverEvents:function(){var a=this.browser.view,b=this;if("collapsed"==this.displayMode)this._mouseoverEvent&&
(this._mouseoverEvent.remove(),delete this._mouseoverEvent),this._mouseoutEvent&&(this._mouseoutEvent.remove(),delete this._mouseoutEvent);else{if(!this._mouseoverEvent)this._mouseoverEvent=this.own(k(this.staticCanvas,"mousemove",function(c){var c=i.fix(c),d=a.absXtoBp(c.clientX),d=b.layout.getByCoord(d,void 0===c.offsetY?c.layerY:c.offsetY);b.mouseoverFeature(d,c)}))[0];if(!this._mouseoutEvent)this._mouseoutEvent=this.own(k(this.staticCanvas,"mouseout",function(){b.mouseoverFeature(void 0)}))[0]}},
_makeLabelTooltip:function(){if(this.showTooltips&&!this.labelTooltip){var a=this.labelTooltip=j.create("div",{className:"featureTooltip",style:{position:"fixed",display:"none",zIndex:19}},document.body);j.create("span",{className:"tooltipLabel",style:{display:"block"}},a);j.create("span",{className:"tooltipDescription",style:{display:"block"}},a)}},_connectEventHandlers:function(a){for(var b in this.eventHandlers)(function(b,d){var e=this;a.own(k(this.staticCanvas,b,function(b){var b=i.fix(b),c=
e.browser.view.absXtoBp(b.clientX);if(a.containsBp(c)&&(c=e.layout.getByCoord(c,void 0===b.offsetY?b.layerY:b.offsetY))){var m=a.fRectIndex.getByID(c.id());d.call({track:e,feature:c,fRect:m,block:a,callbackArgs:[e,c,m]},c,m,a,e,b)}}))}).call(this,b,this.eventHandlers[b])},getRenderingContext:function(a){if(!a.block||!a.block.featureCanvas)return null;try{return a.block.featureCanvas.getContext("2d")}catch(b){return console.error(b,b.stack),null}},renderFeatures:function(a,b){var c=this.getRenderingContext(a);
if(c){var d=this;g.forEach(b,function(a){a&&d.renderFeature(c,a)})}},mouseoverFeature:function(a,b){if(this.lastMouseover!=a){if(b)var c=this.browser.view.absXtoBp(b.clientX);if(this.labelTooltip)this.labelTooltip.style.display="none";g.forEach(this.blocks,function(d){if(d){var e=this.getRenderingContext({block:d,leftBase:d.startBase,scale:d.scale});if(e){if(this.lastMouseover){var f=d.fRectIndex.getByID(this.lastMouseover.id());f&&this.renderFeature(e,f)}d.tooltipTimeout&&window.clearTimeout(d.tooltipTimeout);
if(a){var h=d.fRectIndex.getByID(a.id());if(h){if(d.containsBp(c))f=dojo.hitch(this,function(){if(this.labelTooltip){var c=h.label||h.glyph.makeFeatureLabel(a),d=h.description||h.glyph.makeFeatureDescriptionLabel(a);if(c||d){if(!this.ignoreTooltipTimeout)this.labelTooltip.style.left=b.clientX+"px",this.labelTooltip.style.top=b.clientY+15+"px";this.ignoreTooltipTimeout=!0;this.labelTooltip.style.display="block";if(c){var e=this.labelTooltip.childNodes[0];e.style.font=c.font;e.style.color=c.fill;e.innerHTML=
c.text}if(d)c=this.labelTooltip.childNodes[1],c.style.font=d.font,c.style.color=d.fill,c.innerHTML=d.text}}}),this.ignoreTooltipTimeout?f():d.tooltipTimeout=window.setTimeout(f,600);h.glyph.mouseoverFeature(e,h);this._refreshContextMenu(h)}}else d.tooltipTimeout=window.setTimeout(dojo.hitch(this,function(){this.ignoreTooltipTimeout=!1}),200)}}},this);this.lastMouseover=a}},cleanupBlock:function(a){this.inherited(arguments);a&&this.layout&&this.layout.discardRange(a.startBase,a.endBase)},renderFeature:function(a,
b){b.glyph.renderFeature(a,b)},_trackMenuOptions:function(){var a=this.inherited(arguments),b=this;this.displayModeMenuItems=["normal","compact","collapsed"].map(function(a){return{label:a,type:"dijit/CheckedMenuItem",title:"Render this track in "+a+" mode",checked:b.displayMode==a,onClick:function(){b.displayMode=a;b._clearLayout();b.hideAll();b.genomeView.showVisibleBlocks(!0);b.makeTrackMenu()}}});dojo.hitch(this,function(){for(var a in this.displayModeMenuItems)this.displayModeMenuItems[a].checked=
this.displayMode==this.displayModeMenuItems[a].label});a.push.apply(a,[{type:"dijit/MenuSeparator"},{label:"Display mode",iconClass:"dijitIconPackage",title:"Make features take up more or less space",children:this.displayModeMenuItems},{label:"Show labels",type:"dijit/CheckedMenuItem",checked:!!("showLabels"in this?this.showLabels:this.config.style.showLabels),onClick:function(){b.showLabels=this.checked;b.changed()}}]);return a},_exportFormats:function(){return[{name:"GFF3",label:"GFF3",fileExt:"gff3"},
{name:"BED",label:"BED",fileExt:"bed"},{name:"SequinTable",label:"Sequin Table",fileExt:"sqn"}]},updateStaticElements:function(a){this.inherited(arguments);if(a.hasOwnProperty("x")){var b=this.staticCanvas.getContext("2d");this.staticCanvas.width=this.browser.view.elem.clientWidth;this.staticCanvas.style.left=a.x+"px";b.clearRect(0,0,this.staticCanvas.width,this.staticCanvas.height);var c=this.browser.view.minVisible(),d=this.browser.view.maxVisible(),e={minVisible:c,maxVisible:d,bpToPx:dojo.hitch(this.browser.view,
"bpToPx"),lWidth:this.label.offsetWidth};g.forEach(this.blocks,function(a){if(a&&a.fRectIndex){var a=a.fRectIndex.byID,c;for(c in a){var d=a[c];d.glyph.updateStaticElements(b,d,e)}}},this)}},heightUpdate:function(a,b){this.inherited(arguments);this.staticCanvas.height=this.staticCanvas.offsetHeight},destroy:function(){this.destroyed=!0;j.destroy(this.staticCanvas);delete this.staticCanvas;delete this.layout;delete this.glyphsLoaded;this.inherited(arguments)}})});