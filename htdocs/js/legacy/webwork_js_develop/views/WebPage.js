define(['Backbone','Closeable'], function(Backbone,Closeable){
	var WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    initialize: function () {
    	_.bindAll(this,"render");
    	_.extend(this,this.options);
    },
    render: function () {
    	var self = this; 


        // Create an announcement pane for successful messages.
        this.announce = new Closeable({classes: ["alert-success"], id: "announce-pane"});
        this.$el.prepend(this.announce.el);
        
        // Create an announcement pane for error messages.
        this.errorPane = new Closeable({classes: ["alert-error"], id: "error-pane"});
        this.$el.prepend(this.errorPane.el);
        
        // This is the help Pane
        this.helpPane = new Closeable({closeableType : "Help", text: $("#help-text").html(), id: "help-pane"});
        this.$el.prepend(this.helpPane.el);

        $("button#help-link").click(function () {
                self.helpPane.open();});

    }
    });
    return WebPage;
});