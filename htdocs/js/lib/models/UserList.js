define(['Backbone', 'underscore', './User', 'config'], function(Backbone, _, User, config){
    var UserList = Backbone.Collection.extend({
        model: User,
        url: function () {
	        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users";
	    }

    });

    
    return UserList;
});