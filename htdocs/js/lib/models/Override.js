/**
  * This is a class for ProblemSetPropertyOveride objects.  
  * 
  */

define(['Backbone', 'underscore','config'], function(Backbone, _,config){
    var ProblemSetOverride = Backbone.Model.extend({
    	defaults:  { 
    		user_id: "", 
    		due_date: "", 
    		open_date: "",
    		answer_date: ""},

       update: function(){  // saves the entire Collection to the server.  
            var self = this;
            var requestObject = { xml_command: "saveUserSets", set_id: this.collection.problemSet.get("set_id")};
            _.defaults(requestObject,config.requestObject);

            requestObject.overrides = JSON.stringify([this.attributes]);

            $.post(config.webserviceURL,requestObject,function(data){
                console.log(data);
            })

        } 
    });

    return ProblemSetOverride;
});