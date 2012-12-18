define(['Backbone', 'underscore','config'], function(Backbone, _, config){
    var User = Backbone.Model.extend({
        defaults:{
            first_name: "",
            last_name: "",
            student_id: "",
            user_id: "",
            email_address: "",
            permission: {name: "student", value: 0}, //student
            status: "C", //enrolled
            section: "",
            recitation: "",
            comment: "",
            userpassword: ""
        },
    
        initialize: function(){
            this.on('change',this.update);
        },
    
        update: function(){
            
            console.log("in config.User update");
            var self = this;
            var requestObject = {
                "xml_command": 'editUser'
            };
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);
    
            
            requestObject.permission = requestObject.permission.value;
            console.log(requestObject.permission);
    
            $.post(config.webserviceURL, requestObject, function(data){
                console.log(data);
                var response = $.parseJSON(data);
                var user = response.result_data;
                self.set(user);
                
                // if this is successful, then report back by triggering a updateSuccess event
                // Somehow it would be nice to deliver whether a general update of user information was made
                // or a password change.  
                
                if (self.attributes.new_password == undefined)
                { self.trigger("success","general");} else
                {self.trigger("success", "Password Changed for user " + self.attributes.user_id);}
            });
        },
        
        /*  The following is not need because it is changed in the edit User above */
    
    /*    setPassword:function(new_password){
            var requestObject = {
                "xml_command": 'changeUserPassword',
                'new_password': new_password
            };
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);
    
            requestObject.permission = requestObject.permission.value;
    
            $.post(config.webserviceURL, requestObject, function(data){
                console.log(data);
                console.log("success?");
            });
        } */
    });
    return User;
});