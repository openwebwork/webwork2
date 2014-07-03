/**
  * This is a class for AssignmentDate objects that will be used with an AssignmentDateList collection to be used
  * in a calendar. 
  * 
  */

define(['Backbone', 'underscore','moment'], function(Backbone, _,moment){
	var AssignmentDate = Backbone.Model.extend({
		defaults: {
			type: "", // type of assignment Date (open, due, answer, reduced)
			date : "", // date of assignment date
		}
	});

	return AssignmentDate;
});