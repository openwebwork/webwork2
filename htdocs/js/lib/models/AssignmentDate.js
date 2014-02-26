/**
  * This is a class for AssignmentDate objects that will be used with an AssignmentDateList collection to be used
  * in a calendar. 
  * 
  */

define(['Backbone'], function(Backbone){
	var AssignmentDate = Backbone.Model.extend({
		defaults: {
			type: "", // type of assignment Date (open, due, answer, reduced)
			date : "", // date of assignment date
		}
	});

	return AssignmentDate;
});