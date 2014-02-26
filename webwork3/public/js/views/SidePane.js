define(['backbone'],function(Backbone){
	var SidePane = Backbone.View.extend({
		setMainView: function(view){
			this.mainView = view;
		}
	});

	return SidePane;
});