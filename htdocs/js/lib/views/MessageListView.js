/*
 *  This is a Message View for delivering messages to the user
 *
 */

define(['Backbone','underscore','models/MessageList','models/Message'], function(Backbone, _,MessageList,Message){
	var MessageListView = Backbone.View.extend({
		id: "message-pane",
		isOpen: false,
		initialize: function () {
			_.bindAll(this,"open");
            this.messages = new MessageList();
		},
		render: function() {
			this.$el.html($("#message-pane-template").html());
			$("#short-message").on("click",this.open);

			return this;
		},
		events: {"click .close": "close"},
		open: function(){
			var self = this;
			var ul = this.$(".main-message-pane").empty();
			this.messages.each(function(msg){
				ul.append( (new MessageView({model: msg})).render().el);
			});
			if(! this.isOpen){
				this.$el.fadeIn("slow", function () { self.$el.css("display","block"); });
				this.isOpen = true;
			}
		},
		close: function(){
			var self = this;
			if(this.isOpen){
				this.$el.fadeOut("slow", function () { self.$el.css("display","none"); });
				this.isOpen = false;
			}
		},
		toggle: function (){
			if(this.isOpen){
				this.close();
			} else {
				this.open();
			}
		},
		addMessage: function(msg){
			$("#short-message").removeClass("alert-success").removeClass("alert-error").addClass("alert-" + msg.type)
				.text(msg.short).show("slide", 1000 ).truncate()
			setTimeout(function () {$("#short-message").hide("slide",1000).text("")}, 15000);
			this.messages.add(new Message(msg));
			
		}
	});

	var MessageView = Backbone.View.extend({
		tagName: "li",
		initialize: function () {
          
		},
		render: function() {
			this.$el.addClass("alert").addClass("alert-"+this.model.get("type"));
			this.$el.text(this.model.get("text"));
			return this;
		},
	});

	return MessageListView;
});
