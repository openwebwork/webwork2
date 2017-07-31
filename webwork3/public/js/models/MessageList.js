/*
 *  This is a listing of the messages.
 *
 *
 */


define(['backbone', 'underscore','config','./Message'], function(Backbone, _, config,Message){
    var MessageList = Backbone.Collection.extend({
        model: Message,
        comparator: function(msg1,msg2){
        	return msg1.get("date_created").isBefore(msg2.get("date_created"))?-1:1;
        }
    });


    return MessageList;
});
