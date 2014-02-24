define(['backbone','models/PastAnswer','config'], function(Backbone,PastAnswer,config){
	var PastAnswerList = Backbone.Collection.extend({
		initialize: function(models,options){
			this.userSet= options.userSet;
			this.problem= options.problem;
		},
		model: PastAnswer,
		url: function () {
			return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.userSet.get("user_id")
				+ "/sets/" + this.userSet.get("set_id")+ "/problems/" + 
				(this.problem? this.problem.get("problem_id"):"0") + "/pastanswers";
		}

	});

	return PastAnswerList;
});