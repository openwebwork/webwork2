define(['Backbone', 'underscore'], function(Backbone, _){
    var Closeable = Backbone.View.extend({
        className: "closeablePane",
        text: "",
        display: "none",
        initialize: function(){
    	var self = this; 
    	_.bindAll(this, 'render','setHTML','close','clear','appendHTML','open'); // every function that uses 'this' as the current object should be in here
            if (this.options.text !== undefined) {this.text = this.options.text;}
            if (this.options.display !== undefined) {this.display = this.options.display;}
    	this.$el.addClass("alert");
    	_(this.options.classes).each(function (cl) {self.$el.addClass(cl);});
    	
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

            if (this.$el.height()>0.3*screen.height) {
                this.$el.css("overflow","scroll");
                this.$el.height(0.3*screen.height);
            }
        }
    });
    return Closeable;
});