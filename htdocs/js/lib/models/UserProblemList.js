define(['Backbone', 'models/ProblemList','models/UserProblem'], function(Backbone, ProblemList,UserProblem){
	var UserProblemList = ProblemList.extend({
		model: UserProblem

	});

	return UserProblemList;
});