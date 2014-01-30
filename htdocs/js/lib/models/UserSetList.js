/** 
 *  This is a backbone collection of UserSets
 *
 *   There are two types of UserSetLists:  
 *      1) a list of userSets for a given problemsSet (that is a list of users)
 *      2) a list of userSets for a given user (this is a list of problemSets) 
 *
 *   The difference depends on the options passed to it either a problemSet or a user
 * 
 */


define(['Backbone', 'underscore','./UserSet','config','moment'], function(Backbone, _, UserSet,config,moment){
    var UserSetList = Backbone.Collection.extend({
        model: UserSet,
        initialize: function (models,options) {
            this.problemSet = options? options.problemSet : null;
            this.user = options? options.user : null;
        },
        url: function () {
            if(this.problemSet){ // this is a collection of userSets for a given ProblemSet
                return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.problemSet.get("set_id") + 
                '/users';
            } else { // this is a collection of userSets for a given user
                return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.user + "/sets";
            }
        }
    });

    return UserSetList;
});