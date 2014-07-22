define(['backbone'],function(Backbone){
	var Sidebar = Backbone.View.extend({
		initialize: function(options){
			this.state = new Backbone.Model({is_open: false});
			this.info = options.info;
		},
		setMainView: function(view){
			this.mainView = view;
			return this;
		},
		render: function() {
			// this makes sure that the content fits vertically in the sidebar. 
			var h = $(window).height()-$("#menu-navbar-collapse").height()-$("#sidebar-container .sidebar-name").height() - 110; 
			this.$el.height(h);
			$(this.$el.children().get(0)).height(h).css("overflow-y","auto");
			return this;
		},
		// the follow can be overridden if the state is not stored in a Backbone Model called this.state.
		getState: function () {
            return this.state.attributes;
        },
        setState: function (_state) {
            if(_state){
                this.state.set(_state);
            }
            return this;
        },

	});

	return Sidebar;
});