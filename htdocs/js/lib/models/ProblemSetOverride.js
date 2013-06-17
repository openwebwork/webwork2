/**
  * This is a class for ProblemSetPropertyOveride objects.  
  * 
  */

define(['Backbone', 'underscore'], function(Backbone, _){
    var ProblemSetPropertyOverride = Backbone.Model.extend({
    	defaults:  { 
    		user_id: "", 
    		due_date: "", 
    		open_date: "",
    		answer_date: ""} 
    });

    return ProblemSetPropertyOverride;
});