define(['backbone', 'models/Problem'], function(Backbone, Problem){
	var UserProblem = Problem.extend({
		defaults: {
			user_id: "",
			problem_seed: 1,
			status: "",
			attempted: 0,
			last_answer: "",
			num_correct: 0,
			num_incorrect: 0,
			sub_status: "",
		}
	});

	return UserProblem;
});
