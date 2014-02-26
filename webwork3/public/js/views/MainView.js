define(['backbone'],function(Backbone){
	var MainView = Backbone.View.extend({
		setSidePane: function(pane){
			this.optionPane = pane;
			this.stopListening(this.optionPane);
		}
	});

	return MainView;
});