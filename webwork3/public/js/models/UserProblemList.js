define(['backbone', 'models/ProblemList','models/UserProblem','config'], function(Backbone, ProblemList,UserProblem,config){
	var UserProblemList = ProblemList.extend({
		initialize: function(models,options){
			this.user_id = options.user_id;
			this.set_id = options.set_id;
		},
		model: UserProblem,
		url: function(){
			return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.set_id +
				"/users/" + this.user_id + "/problems";
		}

	});

	return UserProblemList;
});