
webwork.User = Backbone.Model.extend({
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
            _.extend(requestObject, user.attributes);
            _.defaults(requestObject, webwork.requestObject);
            
            $.post(webwork.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
            });
            
            }, this);
        this.on('remove', function(user){
            var request = {"xml_command": "deleteUser", "user_id" : user.user_id };
	    _.defaults(request,webwork.requestObject);
            _.extend(request, user.attributes);
            console.log(request);
	    $.post(webwork.webserviceURL,request,function (data) {
                
                console.log(data);
                var response = $.parseJSON(data);
                // see if the deletion was successful. 
    
               return (response.result_data.delete == "success")
            });

            
        }, this);
        
        // This is used to temporarily add a single (hard coded) student. 
        this.on('addstudent',function(user){
            var u = new webwork.User({user_id:"hsimp",first_name:"Homer", last_name:"Simpson",email_address:"homer@msn.com",
                                     section:"1",student_id:"1234",comment:"This is a comment",recitation:"7"});
            
            console.log("in addstudent")
            console.log(u);
            this.add(u);
        })
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
            self.reset(users);
        });
    },
    email: function(students){

    }
    
});

webwork.userProps = [{shortName: "user_id", longName: "Login Name"},
                     {shortName: "first_name", longName: "First Name"},
                     {shortName: "last_name", longName: "Last Name"},
                     {shortName: "email_address", longName: "Email"},
                     {shortName: "student_id", longName: "Student ID"},
                     {shortName: "status", longName: "Status"},
                     {shortName: "section", longName: "Section"},
                     {shortName: "recitation", longName: "Recitation"},
                     {shortName: "comment", longName: "Comment"},
                     {shortName: "permission", longName: "Permission Level"},
                     {shortName: "userpassword", longName: "Password"}];