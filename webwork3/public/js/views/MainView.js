define(['backbone'],function(Backbone){
	var MainView = Backbone.View.extend({
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
		}
	});

	return MainView;
});