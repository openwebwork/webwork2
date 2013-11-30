define(['Backbone', './UserSet'], function(Backbone, _,config,ProblemSet){
    return  UserSet.extend({ idAttribute: "user_id"});
});