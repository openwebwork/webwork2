/**
  * This is a class for UserSet objects.  
  *
  * 
  */

define(['Backbone', 'underscore','config','./ProblemSet'], function(Backbone, _,config,ProblemSet){
    var UserSet = ProblemSet.extend({
        /*initialize: function (options) {
            console.log("UserSet initialize");
            console.log(this.attributes);
            console.log(options);
        }, */
        url: function () {
            return "/test/courses/" + config.requestObject.courseID + "/users/" + this.get("user_id") +
            "/sets/" + this.get("set_id");
        },
        parse: function (response) {
            config.checkForErrors(response);
            this.id = response.user_id;
            return response;
        },

    });

    return UserSet;
});