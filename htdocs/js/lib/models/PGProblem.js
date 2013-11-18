/**
  * This is a class for editing problems (PGProblem) objects.  
  * 
  */

define(['Backbone', 'underscore','models/DBFields'], function(Backbone, _,DBFields){
    var PGProblem = Backbone.Model.extend({
    	defaults:  { 

    		macros: [],
    		preamble: "",
    		statement: void 0,
            description: "",
    		answer: "",
    		hint: "",
    		solution: "",
    		path: "",
            date: "",
            problem_author: "",
            institution: "",
            textbook_title: "",
            textbook_author: "",
            textbook_edition: "",
            textbook_section: "",
            textbook_problem_number: "",
            db_fields: "",
		},
        validation: {
            statement: { required: true}
        },
        initialize: function (){
            db_field = new DBFields();
        }

    		
    });

    return PGProblem;
});