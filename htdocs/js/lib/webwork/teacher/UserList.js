define(['Backbone', 'underscore', './User', 'config'], function(Backbone, _, User, config){
    var UserList = Backbone.Collection.extend({
        model: User,
    
        initialize: function(){
            var self = this;
            this.on('add', function(user){
                var self = this;
                var requestObject = {"xml_command": 'addUser'};
                _.extend(requestObject, user.attributes);
                _.defaults(requestObject, config.requestObject);
                
                $.post(config.webserviceURL, requestObject, function(data){
                    var response = $.parseJSON(data);
                    self.trigger("success","user_added", user);
                });
                
                }, this);
            this.on('remove', function(user){
                var request = {"xml_command": "deleteUser", "user_id" : user.user_id };
            _.defaults(request,config.requestObject);
                _.extend(request, user.attributes);
                console.log(request);
            $.post(config.webserviceURL,request,function (data) {
                    
                    console.log(data);
                    var response = $.parseJSON(data);
                    // see if the deletion was successful. 
        
                   self.trigger("success","user_deleted",user);
                   return (response.result_data.delete == "success")
                });
    
                
            }, this);
            
           },
    
        fetch: function(){
            var self = this;
            var requestObject = {
                "xml_command": 'listUsers'
            };
            _.defaults(requestObject, config.requestObject);
    
            $.post(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                console.log(response);
                var users = response.result_data;
                self.reset(users);
                self.trigger("fetchSuccess");
            });
        },
        email: function(students){
    
        }
        
    });
    
    return UserList;
});