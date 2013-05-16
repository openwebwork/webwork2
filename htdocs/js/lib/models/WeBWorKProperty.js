
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
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);

            $.post(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                console.log(response);

            });
        }

	}); 

return WeBWorkProperty;
});