define(['Backbone', 'underscore','config','./Message'], function(Backbone, _, config,Message){
    var MessageList = Backbone.Collection.extend({
        model: Message
    });

    return MessageList;
});