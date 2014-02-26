/** 
 *  This is a backbone collection of UserSets
 *
 *   There are two types of UserSetLists:  
 *      1) a list of userSets for a given problemsSet (that is a list of users)  (this file)
 *      2) a list of userSets for a given user (this is a list of problemSets) (UserSetListOfSets.js)
 *
 */


define(['Backbone', 'underscore','./UserSetOfSets','config'], function(Backbone, _, UserSetOfSets,config){
    var UserSetListOfSets = Backbone.Collection.extend({
        model: UserSetOfSets,
        initialize: function (models,options) {
            this.user = options? options.user : null;
            this.problems = [];
            this.set("problems", this.problems);
        },
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.user + "/sets";
        }
    });

    return UserSetListOfSets;
});