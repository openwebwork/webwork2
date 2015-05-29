define(['backbone', 'underscore','config'], function(Backbone, _, config){
    var User = Backbone.Model.extend({
        initialize: function (model){
            this.changingAttributes = {};
        },
        defaults:{
            first_name: "",
            last_name: "",
            student_id: "",
            user_id: "",
            email_address: "",
            permission: "0", //student
            status: "C", //enrolled
            section: "",
            recitation: "",
            comment: "",
            logged_in: false
        },
        validation: { 
            user_id: "checkLogin",
            email_address: {pattern: "email", required: false}
        }, 
        idAttribute: "_id",
        initialize: function(attrs,opts){
            this.set(this.parse(attrs));
        },
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.get("user_id");
        },
        toCSVString: function (){
            var self = this;
            return (config.userProps.map(function(prop){return self.get(prop.shortName);})).join(",") + "\n";
        },
        parse: function(response){
            // check the response.  Perhaps an error should be thrown a valid value isn't sent from the server. 
            if(response && response.status){
                _(config.enrollment_statuses).each(function(enr){
                    if(_(enr.abbrs).contains(response.status)){
                        response.status = enr.value;        
                    }
                })
                
            }
            return response;
        },
        checkLogin: function(){
            if(!this.get("user_id").match(config.regexp.loginname)){
                return "The login name is not valid (you can only use the characters a-z,A-Z, 1-9, . and _)"; // add to messageTemplate
            }
        },
        userExists: function(users){
            if(users.findWhere({user_id: this.get("user_id")})){
                return "The user with login " + this.get("user_id") + " already exists in this course.";
            }
        }
    });
    return User;
});