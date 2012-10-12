
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
        this.on('change',this.update);
    },

    update: function(){
        
        console.log("in webwork.User update");
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
            self.set(user);  // Not sure why this needs to be explicitly called.  

	    self.trigger("success","property_changed",self)
        });
    },
    validation: {
        user_id: [{
            required: true,
            msg: "You must include a user id (login name)"},
            {
            pattern:/^[a-zA-Z]+[a-zA-Z0-9_]*$/,
            msg: "Your user id (login name) is not value.  It must contain only the characters a-z, A-Z, 0-9, _ and must start with a letter."
        }],
        email_address: [
          {pattern: 'email',
          msg: 'The email address is not valid',
	  required: false}
          ]
    },
    toCSVString: function () {  // creates a string to be used
        var self = this;
         return (_(webwork.userProps).map(function (prop) { return  "\"" + ((prop.shortName ==='permission')? self.get(prop.shortName).value :  self.get(prop.shortName)) + "\"";})).join(",") + "\n";
        
    }
});

webwork.UserList = Backbone.Collection.extend({
    model: webwork.User,

    initialize: function(){
        var self = this;
        this.on('add', function(user){
            var self = this;
            var requestObject = {"xml_command": 'addUser'};
            _.extend(requestObject, user.attributes);
            _.defaults(requestObject, webwork.requestObject);
            
            $.post(webwork.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                self.trigger("success","user_added", user);
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
        _.defaults(requestObject, webwork.requestObject);

        $.post(webwork.webserviceURL, requestObject, function(data){
            var response = $.parseJSON(data);
            var users = response.result_data;
            self.reset(users);
            self.trigger("fetchSuccess");
        });
    },
    email: function(students){

    }
    
});

// Note: these are in the order given in the classlist format for LST files.  

webwork.userProps = [{shortName: "student_id", longName: "Student ID", regexp: "student"},
                     {shortName: "last_name", longName: "Last Name", regexp: "last"},
                     {shortName: "first_name", longName: "First Name", regexp: "first"},
                     {shortName: "status", longName: "Status", regexp: "status"},
                     {shortName: "comment", longName: "Comment", regexp: "comment"},
                     {shortName: "section", longName: "Section", regexp: "section" },
                     {shortName: "recitation", longName: "Recitation", regexp: "recitation"},
                     {shortName: "email_address", longName: "Email", regexp: "email"},
                     {shortName: "user_id", longName: "Login Name", regexp: "login"},
                     {shortName: "userpassword", longName: "Password", regexp: "pass"},
                     {shortName: "permission", longName: "Permission Level", regexp: "permission"}
                     ];

webwork.userTableHeaders = [
                { name: "Select", datatype: "boolean", editable: true},
		{ name: "Action", datatype: "string", editable: true,
                    values: {"action1":"Change Password",
                        "action2":"Delete User","action3":"Act as User",
                        "action4":"Student Progess","action5":"Email Student"}
                },
                { label: "Login Name", name: "user_id", datatype: "string", editable: false },
                { label: "Assigned Sets", name: "num_user_sets", datatype: "string", editable: false },
                { label: "First Name", name: "first_name", datatype: "string", editable: true },
                { label: "Last Name", name:"last_name", datatype: "string", editable: true },
                { label: "Email", name: "email_address", datatype: "string", editable: true },
                { label: "Student ID", name: "student_id", datatype: "string", editable: true },
                { label: "Status", name: "status", datatype: "string", editable: true,
                    values : {
                        "en":"Enrolled",
                        "noten":"Not Enrolled"
                    }
                },
                { label: "Section", name: "section", datatype: "integer", editable: true },
                { label: "Recitation", name: "recitation", datatype: "integer", editable: true },
                { label: "Comment", name: "comment", datatype: "string", editable: true },
                { label: "Permission", name: "permission", datatype: "integer", editable: true,
                    values : {
                        "-5":"guest","0":"Student","2":"login proctor",
                        "3":"grade proctor","5":"T.A.", "10": "Professor",
                        "20":"Admininistrator"
		    }
		}
		
            ];