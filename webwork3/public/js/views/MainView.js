define(['backbone'],function(Backbone){
	var MainView = Backbone.View.extend({
		initialize: function(options){
			this.viewName = options.viewName;
			this.settings = options.settings;
			this.users = options.users;
			this.problemSets = options.problemSets;
			this.eventDispatcher = options.eventDispatcher;
		},
		setParentView: function(parentView){
			this.parentView = parentView;
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
		// the follow should be overriden in each view to set the current state of the view.
		setState: function(state){
			return this;
		},
		getState: function(){
			console.error("The getState() function must be overriden");
		}
	});

	return MainView;
});