/**
  * * This is a class for AssignmentDateList collection to be used
  * in a calendar. 
  */

define(['Backbone', 'underscore','moment','models/AssignmentDate'], function(Backbone, _,moment,AssignmentDate){
	var AssignmentDateList = Backbone.Collection.extend({
		model: AssignmentDate,
	});

	return AssignmentDateList;
});