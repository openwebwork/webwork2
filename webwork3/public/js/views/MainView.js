define(['backbone'],function(Backbone){
	var MainView = Backbone.View.extend({
		initialize: function(options){
			this.viewName = options.viewName;
			this.settings = options.settings;
			this.users = options.users;
			this.problemSets = options.problemSets;
			this.eventDispatcher = options.eventDispatcher;
			this.state = new Backbone.Model({});
		},
		setParentView: function(parentView){
			this.parentView = parentView;
		},
		render: function() {
			var self = this;
			this.$el.prepend($("#open-close-view-template").html());
			// since this won't happen automatically in Backbone's delegate events, call the click event directly. 
			this.$(".open-close-view").off("click").on("click", function(){
				self.eventDispatcher.trigger("open-close-sidepane");
			})
			return this;
		},
		setSidePane: function(pane){
			if(typeof(pane)==="undefined"){
				return;
			}
			var self = this;
			this.optionPane = pane;
			this.stopListening(this.optionPane);
			_(this.sidepaneEvents).chain().keys().each(function(event){
				self.listenTo(self.optionPane,event,self.sidepaneEvents[event]);
			});
		},
		// returns a defualt help template. This should be overriden to return a more helpful template. 
		getHelpTemplate: function () { 
			return $("#help-sidepane-template").html();
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

		additionalEvents: {},
		originalEvents: {},
		events : function() {
	      	return _.extend({},this.originalEvents,this.additionalEvents);
	   }
	});

	return MainView;
});