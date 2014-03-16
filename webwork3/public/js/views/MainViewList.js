define(main_view_paths,function(module,Backbone){
		var theViews = arguments;
	var MainViewList = Backbone.View.extend({
		initialize: function(options){
			var i;
			this.views=[];
			this.viewInfo = theViews[0].config().main_views;
			for(i=2;i<theViews.length;i++){
				var view =  
				this.views.push(_.extend({view: new theViews[i](options)},this.viewInfo.main_views[i-2]));
			}
		},
		getViews: function (){
			return this.views;
		},
		getViewByName: function(_name){
			return _(this.views).findWhere({name: _name}).view;
		}
	});

	return MainViewList;
});
