define(['backbone'],function(Backbone){
	var SidePane = Backbone.View.extend({
		initialize: function(){
			this.state = new Backbone.Model({});
		},
		setMainView: function(view){
			this.mainView = view;
			return this;
		},
		isOpen: false,
		render: function() {
			// this makes sure that the content fits vertically in the sidepane. 
			var h = $(window).height()-$("#menu-navbar-collapse").height()-$("#sidepane-container .sidepane-name").height() - 110; 
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

	return SidePane;
});