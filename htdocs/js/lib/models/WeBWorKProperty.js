
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
            return config.urlPrefix + "courses/" + config.courseSettings.courseID + "/settings/" + this.get("var");
        },
        parse: function(response) {
            config.checkForError(response);
            this.id=this.get("var");
            return response;
        }

	}); 

return WeBWorkProperty;
});