/**
  * This is a class for UserSet objects. 
  * 
  * There are two types of UserSets:
  *     1. a UserSetOfSets (those that go in a collection for a given User) 
  *     2. a UserSetOfUsers (those that go in a collection for a given problemSet)
  * 
  */

define(['backbone', 'underscore','config','models/ProblemSet','models/UserProblemList','apps/util'], 
    function(Backbone, _,config,ProblemSet,UserProblemList,util){
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
            visible: false,
            enable_reduced_scoring: false,
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
        integerFields: ["open_date","reduced_scoring_date","due_date","answer_date",
                    "problem_randorder","attempts_per_version","version_creation_time","version_time_limit",
                    "problems_per_page","versions_per_interval","version_last_attempt_time","time_interval"],
        idAttribute: "_id",
        initialize: function(opts){
            if(_.isObject(opts)){
                _(this.attributes).extend(_(util.parseAsIntegers(opts,this.integerFields)).pick(this.integerFields));    
                var pbs = (opts && opts.problems) ? opts.problems : [];
                if(pbs instanceof UserProblemList){
                    this.problems = pbs;
                } else {
                    this.problems = new UserProblemList(pbs,{user_id: this.get("user_id")});    
                }
                this.attributes.problems = this.problems;
            }
        },
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.get("user_id") +
            "/sets/" + this.get("set_id");
        },
        parse: function(response){
            if(response.problems && _.isArray(response.problems)){
                response.problems = new UserProblemList(response.problems,{user_id: response.user_id,set_id: response.set_id});
            }
            response = util.parseAsIntegers(response,this.integerFields);
            return response;
        }
    });

    return UserSet;
});