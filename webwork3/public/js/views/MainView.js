define(['backbone'],function(Backbone){
	var MainView = Backbone.View.extend({
		setOptionPane: function(pane){
			this.optionPane = pane;
		}
	});

	return MainView;
});