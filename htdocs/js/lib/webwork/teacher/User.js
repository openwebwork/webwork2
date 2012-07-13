
webwork.User = Backbone.Model.extend({
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
        comment: "",
        userpassword: ""
    },

    initialize: function(){
        //console.log("in initialize");
    },

    update: function(){
        var self = this;
        var requestObject = {
            "xml_command": 'editUser'
        };
        _.extend(requestObject, this.attributes);
        _.defaults(requestObject, webwork.requestObject);

        requestObject.permission = requestObject.permission.value;
        console.log(requestObject.permission);

        $.post(webwork.webserviceURL, requestObject, function(data){
            console.log(data);
            var response = $.parseJSON(data);
            var user = response.result_data;
            self.set(user);
            console.log("success");
        });
    },

    setPassword:function(new_password){
        var requestObject = {
            "xml_command": 'changeUserPassword',
            'new_password': new_password
        };
        _.extend(requestObject, this.attributes);
        _.defaults(requestObject, webwork.requestObject);

        requestObject.permission = requestObject.permission.value;

        $.post(webwork.webserviceURL, requestObject, function(data){
            console.log(data);
            console.log("success?");
        });
    }
});

webwork.UserList = Backbone.Collection.extend({
    model: webwork.User,

    initialize: function(){
        this.on('add', function(user){
            var self = this;
            var requestObject = {"xml_command": 'addUser'};
            _.extend(requestObject, this.attributes);
            _.extend(requestObject, user.attributes);
            _.defaults(requestObject, webwork.requestObject);

            $.post(webwork.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                console.log(response);
                App.model.trigger('reset');
            });
            
            }, this);
        this.on('remove', function(user){}, this);
    },

    fetch: function(){
        var self = this;
        var requestObject = {
            "xml_command": 'listUsers'
        };
        _.defaults(requestObject, webwork.requestObject);

        $.post(webwork.webserviceURL, requestObject, function(data){
            var response = $.parseJSON(data);
            var users = response.result_data;

            var newUsers = new Array();
            self.reset(users);
        });
    },
    email: function(students){

    }    
});