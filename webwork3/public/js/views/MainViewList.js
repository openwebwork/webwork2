define(main_view_paths,function(module,Backbone){
	var mainViews = Array.prototype.slice.call(arguments,2,module.config().main_views.main_views.length+2); // list of only the main views
	var sidepanes = Array.prototype.slice.call(arguments,module.config().main_views.main_views.length+2);
	var MainViewList = Backbone.View.extend({
		initialize: function(options){
			var self = this;
			_.extend(options,{viewName: ""})
			this.viewInfo = module.config().main_views;
			this.views = _(mainViews).map(function(view,i){
				options.viewName = self.viewInfo.main_views[i].name;
				return _.extend({view: new view(options)},self.viewInfo.main_views[i]);
			});
			this.sidepanes = _(sidepanes).map(function(sp,i){
				return _.extend({view: new sp(options)},self.viewInfo.sidepanes[i]);
			})
		},
		getViewByName: function(_name){
			return _(this.views).findWhere({name: _name}).view;
		},
		getSidepaneByName: function(_name){
			return _name===""? null :  _(this.sidepanes).findWhere({name: _name}).view;
		}
	});

	return MainViewList;
});
