/***
 * 
 * This is how all of the main views and side bars are passed into the function.  
 * 
 * Note: all of them need to be passed from the server (read in from the config.json file) and passed along in javascript.
 *
 */



define(main_view_paths,function(module,Backbone){
	var mainViewClasses = Array.prototype.slice.call(arguments,2,module.config().main_views.main_views.length+2); // list of only the main views
	var sidebarClasses = Array.prototype.slice.call(arguments,module.config().main_views.main_views.length+2);
	var mainViews = module.config().main_views.main_views;
	var sidebars = module.config().main_views.sidebars;

	/** the mainViewClasses and sidebarClasses are the actual Backbone.View objects (classes) for the main views and sidebars 
	 * the mainViews and sidebars variables are arrays of objects in the file config.json
	 *
	 */ 
	
	var MainViewList = Backbone.View.extend({
		initialize: function(options){
			var self = this;
			this.views = _(mainViews).map(function(view,i){
				var opts = {};
				_.extend(opts,options,{info: _(view).pick("name","id","default_sidebar","other_sidebars")});
				return new mainViewClasses[i](opts);
			});
			this.sidebars = _(sidebars).map(function(_sidebar,i){
				var opts = {};
				_.extend(opts,options,{info: _(_sidebar).pick("name","id")});
				return new sidebarClasses[i](opts); 
			})
		},
		getView: function(_id){
			return _(this.views).find(function(v) { return v.info.id===_id});
		},
		getSidebar: function(_id){
			return _(this.sidebars).find(function(v) { return v.info.id===_id});
		},
		getDefaultSidebar: function(_id){
			var view = this.getView(_id);
			return view ? this.getSidebar(view.info.default_sidebar) : null;
		},
		getOtherSidebars: function(_id){
			var view = this.getView(_id);
			return view ? view.info.other_sidebars : null;
		}
	});

	return MainViewList;
});
