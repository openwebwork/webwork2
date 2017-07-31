/**
  * This is a class for Message objects.
  *
  */

define(['backbone', 'underscore','moment'], function(Backbone, _,moment){
    var Message = Backbone.Model.extend({
    	defaults:  {
    		short: "",
    		type: "success",
	    	text: "",
	    	date_created: null,
	    	expiration: 30  // in seconds
    	},
      initialize: function(opts){
        Backbone.Model.prototype.initialize.call(this,opts);
        this.set("date_created",moment());
      }
    });

    return Message;
});
