/**
  * This is a class for Message objects.  
  * 
  */

define(['Backbone', 'underscore','moment'], function(Backbone, _,moment){
    var Message = Backbone.Model.extend({
    	defaults:  { text: "", dateCreated: moment(), expiration: 30} // in seconds},
    });

    return Message;
});