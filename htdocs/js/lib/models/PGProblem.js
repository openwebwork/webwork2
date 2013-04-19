/**
  * This is a class for editing problems (PGProblem) objects.  
  * 
  */

define(['Backbone', 'underscore','config'], function(Backbone, _,config){
    var PGProblem = Backbone.Model.extend({
    	defaults:  { 
    		metadata: [], 
    		macros: [],
    		preamble: "",
    		problem_statement: "",
    		answer_section: "",
    		hint_section: "",
    		solution_section: "",
    		path: ""
		},
		initialize: function (){

		},
		parse: function(str){

		},
		fetch: function(){

		},
		save: function(prob){
			var self = this;
            var requestObject ={xml_command: "saveProblem"};

            _.defaults(requestObject, config.requestObject,this.attributes, {pgCode: prob});

            $.post(config.webserviceURL, requestObject, function (data) {
            	console.log("Saving the file at path:" + this.path);
            	console.log(data);
            });
    

		}
    		
    });

    return PGProblem;
});