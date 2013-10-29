/**
  * This is the assignment calendar view. 
  *
  */


define(['Backbone', 'underscore', 'moment','views/CalendarView','config'], 
    function(Backbone, _, moment,CalendarView,config) {
	
    var AssignmentCalendarView = CalendarView.extend({
    	template: _.template($("#calendar-date-bar").html()),
        headerInfo: { template: "#calendar-header"}, 
    	initialize: function () {
    		this.constructor.__super__.initialize.apply(this, {el: this.el});
    		_.bindAll(this,"render","renderDay");

    		this.assignmentDates = this.options.assignmentDates;
            this.users = this.options.users; 

    		this.reducedScoringMinutes = this.options.reducedScoringMinutes;
    	},
    	render: function (){
    		this.constructor.__super__.render.apply(this);

    		this.$(".assign").popover({html: true});
            this.$(".assign").truncate({width: 100});
    	},
    	renderDay: function (day){
    		var self = this;
            var assignments = this.assignmentDates.where({date: day.model.format("YYYY-MM-DD")});
            _(assignments).each(function(assign){
                day.$el.append(self.template({classes: "assign assign-" + assign.get("type"), 
                    setname: assign.get("problemSet").get("set_id"), 
                    assignedUsers: assign.get("problemSet").get("assigned_users").length, 
                    totalUsers: self.users.length, visibleToStudents: assign.get("problemSet").get("visible"),
                    showName: true}));
            });
    	}
    });

	return AssignmentCalendarView;
});
