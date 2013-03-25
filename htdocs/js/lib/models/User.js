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
    
            // store the changed attribute. 

            this.oldAttributes = _.clone(this.changedAttributes());

            for(prop in this.changedAttributes())
            {
                this.oldAttributes[prop] = this.previous(prop);
            }

            requestObject.permission = requestObject.permission.value;
            console.log(requestObject.permission);
    
            $.post(config.webserviceURL, requestObject, function(data){
                console.log(data);
                var response = $.parseJSON(data);
                var user = response.result_data;
                
                
                // if this is successful, then report back by triggering a updateSuccess event
                // Somehow it would be nice to deliver whether a general update of user information was made
                // or a password change.  
                self.trigger("success","property_changed", self);
            });
        },
        toCSVString: function (){
            var self = this;
            return (config.userProps.map(function(prop){return self.get(prop.shortName);})).join(",") + "\n";
        }
    });
    return User;
});