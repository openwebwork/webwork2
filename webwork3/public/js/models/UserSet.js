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
        idAttribute: "_id",
        initialize: function(opts,dateSettings){
            if(_.isObject(opts)){
                _(this.attributes).extend(_(util.parseAsIntegers(opts,this.integerFields))
                                          .pick(this.integerFields));    
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
        }
    });

    return UserSet;
});