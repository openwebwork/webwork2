/** 
 *  This is a backbone collection of UserSets
 *
 *   There are two types of UserSetLists:  
 *      users: a list of userSets for a given problemsSet (that is a list of users) 
 *      sets: a list of userSets for a given user (this is a list of problemSets) 
 *   
 *   If the type is not defined, then an error will be thrown. 
 */


define(['backbone','models/UserSet','config'], function(Backbone, UserSet,config){
    var UserSetList = Backbone.Collection.extend({
        model: UserSet,
        initialize: function (models,options) {
            this.problemSet = options ? options.problemSet : null;
            this.user = options ? options.user : null;
            this.type = options ? options.type : "";
            this.loadProblems = options.loadProblems || false; 
            this.problems = [];
            this.set("problems", this.problems);
        },
        url: function () {
            switch(this.type){
                case "sets": 
                    if(typeof(this.user)==="undefined"){
                        console.error("UserSetList error. The user field must be defined.");
                    }
                    if(this.loadProblems){
                        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.user + "/sets/all/problems";
                    } else {
                        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.user + "/sets";
                    }
                case "users":
                    if(typeof(this.problemSet)==="undefined"){
                        console.error("UserSetList error. The problemSet field must be defined.");
                    }
                    if(this.loadProblems){
                        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/"
                            + this.problemSet.get("set_id") + "/users/all/problems";
                    } else {
                        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" 
                            + this.problemSet.get("set_id") + '/users';
                    }
                default: 
                    console.error("The type of UserSet must be either 'sets' or 'users'. ");
            }
        }
    });

    return UserSetList;
});