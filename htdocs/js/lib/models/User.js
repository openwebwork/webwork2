define(['Backbone', 'underscore','config'], function(Backbone, _, config){
    var User = Backbone.Model.extend({
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
        validation: { user_id: {pattern: "loginname"},
                        email_address: {pattern: "email"}
                    }, 
    
        initialize: function(){
            //this.on('change',this.update);
            //this.on('change',function() {console.log(this.attributes)});
        },
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.courseID + "/users/" + this.get("user_id");
        },
        toCSVString: function (){
            var self = this;
            return (config.userProps.map(function(prop){return self.get(prop.shortName);})).join(",") + "\n";
        },
        parse: function(response) {
            this.id=response? response.user_id : this.get("user_id");
            return response;
        }
    });
    return User;
});