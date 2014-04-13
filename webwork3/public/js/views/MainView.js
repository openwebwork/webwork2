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
		render: function() {
			var self = this;
			this.$el.prepend($("#open-close-view-template").html());
			// since this won't happen automatically in Backbone's delegate events, call the click event directly. 
			this.$(".open-close-view").off("click").on("click", function(){
				/*var it = self.$(".open-close-view i");
				if(it.hasClass("fa-chevron-right")){
					it.removeClass("fa-chevron-right").addClass("fa-chevron-left")
				} else {
					it.removeClass("fa-chevron-left").addClass("fa-chevron-right")
				} */
				self.eventDispatcher.trigger("open-close-sidebar");
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