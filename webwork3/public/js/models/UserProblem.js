define(['backbone', 'models/Problem'], function(Backbone, Problem){
	var UserProblem = Problem.extend({
		defaults: {
			user_id: "",
			problem_seed: "",
			status: "",
			attempted: "", 
			last_answer: "",
			num_correct: "",
			num_incorrect: "",
			sub_status: "", 
		}
	});

	return UserProblem;
});