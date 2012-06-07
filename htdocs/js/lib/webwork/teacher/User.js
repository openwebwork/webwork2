
webwork.User = Backbone.Model.extend({
    defaults:{
        firstname: "",
        lastname: "",
        id: "",
        email: "",
        permission: "student",
        status: "C", //enrolled
        section: "",
        recitation: "",
        comment: "",
        userpassword: ""


    },

    initialize: function(){
    },

    fetch: function(){

    },

    update: function(){
        var requestObject = {
            "xml_command": 'editUser'
        };
        _.extend(requestObject, this.attributes);
        _.defaults(requestObject, webwork.defaultRequestObject);

        $.post(webwork.webserviceURL, requestObject, function(data){
            console.log(data);
            console.log("success?");
        });
    },

    setPassword:function(new_password){
        var requestObject = {
            "xml_command": 'changeUserPassword',
            'new_password': new_password
        };
        _.extend(requestObject, this.attributes);
        _.defaults(requestObject, webwork.defaultRequestObject);

        $.post(webwork.webserviceURL, requestObject, function(data){
            console.log(data);
            console.log("success?");
        });
    }
});

webwork.UserList = Backbone.Collection.extend({
    model: webwork.User,

    initialize: function(){
        this.model.on('add', function(user){}, this);
        this.model.on('remove', function(user){}, this);
    },

    fetch: function(){

    },
    email: function(students){

    }

})