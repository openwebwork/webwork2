/**
  * This is a class for Message objects.  
  * 
  */

define(['Backbone', 'underscore'], function(Backbone, _){
    var Message = Backbone.Model.extend({
    	defaults:  { text: "", dateCreated: new Date(), expiration: 30} // in seconds},
    });

    return Message;
});