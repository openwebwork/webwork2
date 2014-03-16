define(['backbone'], function(Backbone){
	var NavigationBar = Backbone.View.extend({
		render: function (){
			_(this).extend(Backbone.Events);
			this.$el.html($("#menu-bar-template").html());
			return this;
		},
		events: {
			"click .manager-menu a": function(evt){
				this.trigger("change-view",$(evt.target).data("name"));
			},
			"click .main-help-button": function(evt){
				this.trigger("open-option","Help");
			},
			"click .option-menu a": function(evt){
				this.trigger("open-option",$(evt.target).data("name"));
			}
		},
		setPaneName: function(name){
			this.$(".main-view-name").text(name);
		}, 
		setLoginName: function(name){
			this.$(".logged-in-as").text(name);
		}
	});

	return NavigationBar; 

});
