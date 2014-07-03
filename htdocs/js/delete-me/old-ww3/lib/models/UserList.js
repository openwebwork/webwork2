define(['Backbone', 'underscore', './User', 'config'], function(Backbone, _, User, config){
    var UserList = Backbone.Collection.extend({
        model: User,
    });
    
    return UserList;
});