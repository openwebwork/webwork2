define(['backbone', 'underscore','config','apps/util'], function(Backbone, _, config,util){
    var User = Backbone.Model.extend({
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
            logged_in: false,
            displayMode: "",
            showOldAnswers: false,
            useMathView: false,
            lis_source_did: ""
        },
        validation: {
            user_id: "checkLogin",
            email_address: {pattern: "email", required: false},
            student_id: {required: true}
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
            return (config.userProps.map(function(prop){return util.csvEscape(self.get(prop.shortName));})).join(",") + "\n";
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

            // the permission need to be stored as strings.
            if(response && ! _.isUndefined(response.permission)){
              response.permission = "" + response.permission;
            }
            return response;
        },
        checkLogin: function(opt){
          var user_id = this.get("user_id") || opt;
          if(!user_id.match(config.regexp.loginname)){
              return "The login name is not valid (you can only use the characters a-z,A-Z, 1-9, . and _)"; // add to messageTemplate
          }
        },
        userExists: function(users){
            if(users.findWhere({user_id: this.get("user_id")})){
                return "The user with login " + this.get("user_id") + " already exists in this course.";
            }
        },
        // this is separate from the user fields so information is not saved.
        savePassword: function(passwords,options){
          var success = _.isUndefined(options)? function () {} : (options.success) || function () {};
          var error = _.isUndefined(options)? function () {} : (options.error) || function () {};
          console.log(passwords); 
            $.ajax({
                url: config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.get("user_id")
                        + "/password",
                method: "POST",
                type: "json",
                data: passwords,
                success: success,
                error: error
            })
        }
    });
    return User;
});
