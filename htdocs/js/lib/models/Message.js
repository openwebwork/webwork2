/**
  * This is a class for Message objects.  
  * 
  */

define(['Backbone', 'underscore','XDate'], function(Backbone, _,XDate){
    var Message = Backbone.Model.extend({
    	defaults:  { text: "", dateCreated: XDate.now(), expiration: 30} // in seconds},
    });

    return Message;
});