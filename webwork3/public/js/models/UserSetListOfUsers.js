/** 
 *  This is a backbone collection of UserSets
 *
 *   There are two types of UserSetLists:  
 *      1) a list of userSets for a given problemsSet (that is a list of users)  (UserSetListOfUsers.js)
 *      2) a list of userSets for a given user (this is a list of problemSets) (this file)
 *
 */


define(['backbone', 'underscore','./UserSet','config'], function(Backbone, _, UserSetOfUsers,config){
    var UserSetListOfUsers = Backbone.Collection.extend({
        model: UserSetOfUsers,
        initialize: function (models,options) {
            this.problemSet = options? options.problemSet : null;
        },
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.problemSet.get("set_id") + 
                '/users';
        }
    });

    return UserSetListOfUsers;
});