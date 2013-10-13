define(['Backbone', 'underscore','models/MessageList','models/Message'], 
    function(Backbone, _,MessageList,Message){
    var Closeable = Backbone.View.extend({
        className: "closeablePane",
        text: "",
        display: "none",
        initialize: function(){
        	var self = this; 
            // every function that uses 'this' as the current object should be in here
        	_.bindAll(this, 'render','setHTML','close','clear','appendHTML','open','addMessage','removeMessage','showMessages'); 
            _.extend(this,this.options);
        	this.$el.addClass("alert");
        	_(this.options.classes).each(function (cl) {self.$el.addClass(cl);});
        	
            this.messages = new MessageList();
        	this.render();
        	
        	this.isOpen = false; 
            return this;
        },
        events: {
    	'click button.close': 'close'
        },
        render: function(){
                this.$el.html("<div class='row-fluid'><div class='span11 closeable-text'></div><div class='span1 pull-right'>" +
                              " <button type='button' class='close'>&times;</button></div></div>");
                this.$(".closeable-text").html(this.text);
                this.$el.css("display",this.display);
                
    	    return this; // for chainable calls, like .render().el
    	},
        close: function () {
    	this.isOpen = false; 
            var self = this;
            this.$el.fadeOut("slow", function () { self.$el.css("display","none"); });
        },
        setHTML: function (str) {
            this.$(".closeable-text").html(str);
            if (!this.isOpen){this.open();}
        },
        clear: function () {
    	this.$(".closeable-text").html("");
        },
        appendHTML: function(str) {
    	this.$(".closeable-text").append(str);
    	if (!this.isOpen){this.open();}
    	
        },
        open: function (){
    	    this.isOpen = true;
            var self = this;
            this.$el.fadeIn("slow", function () { self.$el.css("display","block"); });

            if (this.$el.height()>30) {
                this.$el.css("overflow","scroll");
                this.$el.height(30);
            }
        },
        addMessage: function (props){
            var self = this;
            var msg = new Message(props);
            this.messages.add(msg);
            this.showMessages();
            //console.log("add message " + _text + " for " + _expiration + " seconds. ");
            setTimeout(function () {self.removeMessage(msg)}, 1000*parseInt(msg.get("expiration")));
        },
        removeMessage: function (msg) {
            console.log("removing the message");
            msg.destroy();
            this.showMessages();
        },
        showMessages: function() {
            this.setHTML(this.messages.pluck("text").join("<br>"));
            if (this.messages.size() === 0)
                { this.close();}
        }

    });
    return Closeable;
});