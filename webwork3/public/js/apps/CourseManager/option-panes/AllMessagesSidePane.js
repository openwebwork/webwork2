define(['backbone','views/SidePane', 'config'],function(Backbone,SidePane,config){
	var AllMesagesSidePane = SidePane.extend({
		initialize: function(options){
			this.messages = options.messages;
			_(this).bindAll("render");
		},
		set: function(options){
			this.messages = options.messages;
			this.messages.on("add remove change",this.render);
		},
	    render: function(){
	    	if(typeof(this.$el)==="undefined"){
	    		return;
	    	}
	        this.$el.html($("#all-messages-template").html());
	        var messageViewTemplate = $("#message-view-template").html();
	        var ul = this.$(".messages-list");
	        this.messages.each(function(message){
	        	ul.append(new MessageView({model: message}).render().el);
	        })
	        return this;
	    }
	});

	var MessageView = Backbone.View.extend({
		tagName: "li",
		render: function(){
			this.$el.html(this.model.get("text")).addClass("text-" + this.model.get("type"));
			return this; 
		},


	});

	return AllMesagesSidePane;
});