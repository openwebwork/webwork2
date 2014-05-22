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
            permission: 0, //student
            status: "C", //enrolled
            section: "",
            recitation: "",
            comment: ""
        },
        validation: { 
            user_id: {pattern: "loginname"},
            email_address: {pattern: "email", required: false}
        }, 
        idAttribute: "_id",
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.get("user_id");
        },
        toCSVString: function (){
            var self = this;
            return (config.userProps.map(function(prop){return self.get(prop.shortName);})).join(",") + "\n";
        }
    });
    return User;
});