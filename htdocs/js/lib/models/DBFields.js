/**
  * This is a class for storing the Database fields (subject,chapter,section)
  * 
  */

define(['Backbone'], function(Backbone){
    var DBfields = Backbone.Model.extend({
    	defaults:  { 
    		subject: "",
    		chapter: "",
    		section: ""
    	}
    });
    return DBfields;
});