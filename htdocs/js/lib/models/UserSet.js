/**
  * This is a class for UserSet objects. 
  * 
  * There are two types of UserSets:
  *     1. a UserSetOfSets (those that go in a collection for a given User) 
  *     2. a UserSetOfUsers (those that go in a collection for a given problemSet)
  * 
  */

define(['Backbone', 'underscore','config','./ProblemSet'], function(Backbone, _,config,ProblemSet){
    var UserSet = Backbone.Model.extend({
        defaults: {
            user_id: "",
            set_id: "",
            psvn: "",
            set_header: "defaultHeader", 
            hardcopy_header: "",
            open_date: "",
            due_date: "",
            answer_date: "",
            visible: "",
            enable_reduced_scoring: "",
            assignment_type: "",
            description: "",
            restricted_release: "",
            restricted_status: "",
            attempts_per_version: "",
            time_interval: "",
            versions_per_interval: "",
            version_time_limit: "",
            version_creation_time: "",
            problem_randorder: "",
            version_last_attempt_time: "",
            problems_per_page: "",
            hide_score: "",
            hide_score_by_problem: "",
            hide_work: "",
            time_limit_cap: "",
            restrict_ip: "",
            relax_restrict_ip: "",
            restricted_login_proctor: "",
            hide_hint:"" 
        },
        idAttribute: "_id",
        type: "",
/*        url: function () {
            switch(this.type){
                case "sets": 

                case "users":
                    return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.get("user_id") +
                        "/sets/" + this.get("set_id");
                default: 
                    console.error("The type of UserSet must be either 'sets' or 'users'. ");
            }
        }
        */
    });

    return UserSet;
});