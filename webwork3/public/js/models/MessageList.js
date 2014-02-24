define(['backbone', 'underscore','config','./Message'], function(Backbone, _, config,Message){
    var MessageList = Backbone.Collection.extend({
        model: Message,
        comparator: function(msg1,msg2){
        	return msg1.get("dateCreated").isBefore(msg2.get("dateCreated"))?-1:1;
        }
    });


    return MessageList;
});