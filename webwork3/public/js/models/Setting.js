
define(['backbone','underscore','config'], function(Backbone,_,config){
	var Setting = Backbone.Model.extend({
		defaults: {
            doc:"",
            doc2: "",
			value: "",
			type: "",
			category: "",
            "var": ""
		},
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/settings/" + this.get("var");
        },
        idAttribute: "var"

	}); 

return Setting;
});