/**
  * This is a class for UserSet objects.  
  *
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
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.get("user_id") +
            "/sets/" + this.get("set_id");
        },
        idAttribute:'user_id'
    });

    return UserSet;
});