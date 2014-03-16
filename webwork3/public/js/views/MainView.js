define(['backbone'],function(Backbone){
	var MainView = Backbone.View.extend({
		initialize: function(options){
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
		}
	});

	return MainView;
});