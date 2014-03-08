/**
  * This is the assignment calendar view. 
  *
  */


define(['backbone', 'underscore', 'moment','views/CalendarView','config'], 
    function(Backbone, _, moment,CalendarView,config) {
	
    var AssignmentCalendar = CalendarView.extend({
    	template: _.template($("#calendar-date-bar").html()),
        headerInfo: {template: "#calendar-header", events: 
                { "click .previous-week": "viewPreviousWeek",
                    "click .next-week": "viewNextWeek",
                    "click .view-week": "showWeekView",
                    "click .view-month": "showMonthView"}
        },
    	initialize: function (options) {
            var self = this;
    		this.constructor.__super__.initialize.apply(this, [_.extend({el: this.el},options)]);
    		_.bindAll(this,"render","renderDay");

    		this.assignmentDates = options.assignmentDates;
            this.users = options.users; 

    		this.reducedScoringMinutes = options.reducedScoringMinutes;
    	},
    	render: function (){
    		this.constructor.__super__.render.apply(this);

    		this.$(".assign").popover({html: true});
            this.$(".assign").truncate({width: 100});
            // set up the calendar to scroll correctly
            this.$(".calendar-container").height($(window).height()-160);
            return this;
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
    	},
        getHelpTemplate: function (){
            return $("#calendar-help-template").html();
        }
    });

	return AssignmentCalendar;
});
