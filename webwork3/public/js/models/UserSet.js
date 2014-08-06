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
    var UserSet = ProblemSet.extend({
        defaults: function () {
            _.extend({user_id: ""},ProblemSet.prototype.defaults)    
        },
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.get("user_id") +
            "/sets/" + this.get("set_id");
        },
        parse: function(data){
            if(data.problems){
                data.problems = new UserProblemList(data.problems,{user_id: data.user_id,set_id: data.set_id});
            }
            data = util.parseAsIntegers(data,["open_date","reduced_scoring_date","due_date","answer_date"]);
            return data;
        }
    });

    return UserSet;
});