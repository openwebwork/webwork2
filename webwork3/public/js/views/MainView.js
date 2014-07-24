define(['backbone'],function(Backbone){
	var MainView = Backbone.View.extend({
		initialize: function(options){
			var self = this;
			_(this).extend(_(options).pick("settings","users","problemSets","eventDispatcher","info"));
			this.state = new Backbone.Model({});
			this.state.on("change",function(){
				self.eventDispatcher.trigger("save-state");
			});
		},
		render: function() {
			var self = this;
			this.$el.prepend($("#open-close-view-template").html());
			// since this won't happen automatically in Backbone's delegate events, call the click event directly. 
			this.$(".open-view-button").off("click").on("click", function(){
				self.eventDispatcher.trigger("open-sidebar");
			});
			this.$(".close-view-button").off("click").on("click", function(){
				self.eventDispatcher.trigger("close-sidebar");
			});
			return this;
		},
		// returns a defualt help template. This should be overriden to return a more helpful template. 
		getHelpTemplate: function () { 
			return $("#help-sidebar-template").html();
		},
		// the follow can be overridden if the state is not stored in a Backbone Model called this.state.
		getState: function () {
            return this.state.attributes;
        },
		// the follow can be overridden if the state is not stored in a Backbone Model called this.state.
        setState: function (_state) {
            if(_state){
                this.state.set(_state,{silent: true});
            }
            return this;
        },
        // this is how events are handled with children.  Any events defined in the 
        // child of this view should be in "additionalEvents".  
		additionalEvents: {},
		originalEvents: {},
		events : function() {
	      	return _.extend({},this.originalEvents,this.additionalEvents);
	   }
	});

	return MainView;
});