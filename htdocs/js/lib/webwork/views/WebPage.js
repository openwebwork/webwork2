define(['Backbone'], function(Backbone){
	WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    initialize: function () {
//         this.announceView = new ui.CloseableDiv({border: "2px solid darkgreen", background: "lightgreen"});
//         this.helpView = new ui.CloseableDiv();
        },
    });
    return WebPage;
});