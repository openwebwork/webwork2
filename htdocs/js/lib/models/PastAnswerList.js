define(['Backbone','models/PastAnswer','config'], function(Backbone,PastAnswer,config){
	var PastAnswerList = Backbone.Collection.extend({
		model: PastAnswer,
		initialize: function (options){
			this.userSet = options.user_set;
			this.problem = options.problem;
		},
		url: function () {
			return config.urlPrefix + "courses/" + config.courseSettings.courseID + "/users/" + this.userSet.get("user_id")
				+ "/sets/" + this.userSet.get("set_id")+ "/problems/" + this.problem.get("problem_id") 
				+ "/pastanswers";
		}

	});

	return PastAnswerList;
});