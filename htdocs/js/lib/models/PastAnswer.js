define(['Backbone','config'], function(Backbone,config){
	var PastAnswer = Backbone.Model.extend({
		defaults: {answer_id: "",
		    course_id: "",         
		    user_id: "",
		    set_id: "",
		    problem_id: "",
		    source_file: "",
		    timestamp: "",
		    scores: "",
	        answer_string: "",
		    comment_string: ""
		},
		idAttribute: "answer_id"
	});


	return PastAnswer;
});