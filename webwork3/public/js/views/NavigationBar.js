define(['backbone'], function(Backbone){
	var NavigationBar = Backbone.View.extend({
		render: function (){
			_(this).extend(Backbone.Events);
			this.$el.html($("#menu-bar-template").html());
			return this;
		},
		events: {
			"click .manager-menu a.link": function(evt){
				this.trigger("change-view",$(evt.target).data("name"));
			},
			"click .main-help-button": function(evt){
				this.trigger("open-option","Help");
			},
			"click .logout-link": function(evt){ this.trigger("logout");},
			"click .stop-acting-link": function(evt){ this.trigger("stop-acting");},
		},
		setPaneName: function(name){
			this.$(".main-view-name").text(name);
		}, 
		setLoginName: function(name){
			this.$(".logged-in-as").text(name);
		},
		setActAsName: function(name){
			if(name===""){
				this.$(".act-as-user").text("");
				this.$(".stop-acting-li").addClass("disabled");
			} else {
				this.$(".act-as-user").text("("+name+")");
				this.$(".stop-acting-li").removeClass("disabled");
			}
		}
	});

	return NavigationBar; 

});
