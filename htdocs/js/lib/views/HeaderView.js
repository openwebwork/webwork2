/**
 * HeaderView is a view that heads the pane shown.  For Layout purposes, this needs to 
 * be a separate View.  
 *
 *  to call this effectively, you need to call the setTemplate method with an object with fields:
 *    template:  a jquery string to get the template
 *	  templateOptions: an object of options to pass to the template or a function
 *    events: an object of events typical in a Backbone.View
 *
 */

define(['Backbone'], function(Backbone){
    var HeaderView = Backbone.View.extend({
    	initialize: function () {
    		_.bindAll(this,"setOptions","render");
    	},
    	render: function () {
            if(typeof(this.template)!=="undefined" && typeof(this.templateOptions)!=="undefined"){
        		this.$el.html(_.template($(this.template).html(),this.templateOptions))
        		if(this.events){
        			this.delegateEvents(this.events);
        		}
            }
    	},
    	setOptions: function (options){
    		this.template = options.template || "";
            this.templateOptions = typeof(options.options)=="function"?options.options(): (options.options || {});
    		this.events = options.events || "";
    		return this; 
    	}

	});

	return HeaderView;
});