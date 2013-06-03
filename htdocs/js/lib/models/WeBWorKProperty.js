
define(['Backbone','underscore','config'], function(Backbone,_,config){
	var WeBWorkProperty = Backbone.Model.extend({
		defaults: {
			property: "",
			value: "",
			type: "",
			category: ""
		},
         initialize: function(){
            this.on('change',this.update);
        },
    
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
        }

	}); 

return WeBWorkProperty;
});