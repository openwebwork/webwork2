
define(['Backbone','underscore','config'], function(Backbone,_,config){
	var WeBWorkProperty = Backbone.Model.extend({
		defaults: {
			value: "",
			type: "",
			category: "",
            "var": ""
		},
         initialize: function(){
            //this.on('change',this.update);
        },
        url: function () {
            return "/test/courses/" + config.courseSettings.courseID + "/settings/" + this.get("var");
        },
        parse: function(response) {
            config.checkForError(response);
            this.id=this.get("var");
            return response;
        }
/*    
        update: function(){
           
            var self = this;
            var requestObject = {
                "xml_command": 'updateSetting'
            };

            var parameters = _.clone(this.attributes);

            // If the value is an array, encode it as JSON

            if(_.isArray(this.get("value"))){
                parameters.value = JSON.stringify(this.get("value"));
                parameters.sendViaJSON = true; 
            }

            _.extend(requestObject, parameters);
            _.defaults(requestObject, config.requestObject);

            $.post(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                console.log(response);

            });
        } */

	}); 

return WeBWorkProperty;
});