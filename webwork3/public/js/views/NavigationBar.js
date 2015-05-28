define(['backbone'], function(Backbone){
	var NavigationBar = Backbone.View.extend({
		render: function (){
			_(this).extend(Backbone.Events);
			this.$el.html($("#menu-bar-template").html());
			return this;
		},
		events: {
			"click .manager-menu a.link": function(evt){
                // if the icon is clicked on, then need to select the parent.
                var id= $(evt.target).data("id");
                if(typeof(id)==="undefined"){
                    id = $(evt.target).parent().data("id");
                }
                this.trigger("change-view",id)
            },
			"click .main-help-button": function(evt){
				this.trigger("show-help")},
			"click .logout-link": function(evt){ this.trigger("logout")},
			"click .stop-acting-link": function(evt){ this.trigger("stop-acting")},
			"click .forward-button": function(){ this.trigger("forward-page")},
			"click .back-button": function(){ this.trigger("back-page")},
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
