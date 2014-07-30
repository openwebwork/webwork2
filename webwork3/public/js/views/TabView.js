define(['backbone'],function(Backbone){
	var TabView = Backbone.View.extend({
		initialize: function(options){
			var self = this;
			_(this).extend(_(options).pick("eventDispatcher"));
			this.tabState = new Backbone.Model({});
			this.tabState.on("change",function(){
				console.log("TabView state changing");
				self.eventDispatcher.trigger("save-state");
			})
			this.tabState.set(this.getDefaultState(),{silent: true});
		},
		getDefaultState: function () {
			console.error("getDefaultState needs to be overridden for tab name " + this.name);
		}
	});
	return TabView;
});

