define(['backbone'],function(Backbone){
	var SidePane = Backbone.View.extend({
		setMainView: function(view){
			this.mainView = view;
			return this;
		},
		isOpen: false,
		render: function() {
			// this makes sure that the content fits vertically in the sidepane. 

			var h = $(window).height()-$("#menu-navbar-collapse").height()-$("#sidepane-container .sidepane-name").height() - 110; 
			this.$el.height(h);
			$(this.$el.children().get(0)).height(h).css("overflow-y","auto")
		}
	});

	return SidePane;
});