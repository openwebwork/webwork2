define(['Backbone'],function(Backbone){
	var MainView = Backbone.View.extend({
		setOptionPane: function(pane){
			this.optionPane = pane;
		}
	});

	return MainView;
});