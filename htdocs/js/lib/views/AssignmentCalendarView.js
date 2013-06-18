/**
  * This is the assignment calendar view. 
  *
  */


define(['Backbone', 'underscore', 'moment','./CalendarView','config'], 
    function(Backbone, _, moment,CalendarView,config) {
	
    var AssignmentCalendarView = CalendarView.extend({
    	template: _.template($("#calendar-date-bar").html()),
    	initialize: function () {
    		this.constructor.__super__.initialize.apply(this, {el: this.el});
    		_.bindAll(this,"render","renderDay","createAssignInfoBar");

    		this.problemSets = this.options.problemSets; 
            this.users = this.options.users; 

    		this.reducedScoringMinutes = this.options.reducedScoringMinutes;
    	},
    	render: function (){
    		this.constructor.__super__.render.apply(this);

    		this.$(".assign").popover({html: true});
    	},
    	renderDay: function (day){
    		var self = this;
    		this.problemSets.each(function(assign){
    			if(moment.unix(assign.get("due_date")).isSame(day.model,"day")){
    				day.$el.append(self.createAssignInfoBar(assign,"assign assign-due"));
    			}
    			if(moment.unix(assign.get("open_date")).isSame(day.model,"day")){
    				day.$el.append(self.createAssignInfoBar(assign,"assign assign-open"));
    			}
    			var reducedScoreDate = moment.unix(assign.get("due_date")).subtract("minutes",self.reducedScoringMinutes);
    			if((assign.get("reduced_scoring_enabled")===1) & reducedScoreDate.isSame(day.model,"day")){
					day.$el.append(self.createAssignInfoBar(assign,"assign assign-reduced-credit"));
    			}
    		});
    	},
    	createAssignInfoBar: function(assign,_classes){
    		return this.template({classes: _classes, setname: assign.get("set_id"), 
    				assignedUsers: assign.get("assigned_users").length, totalUsers: this.users.length, visibleToStudents: assign.get("visible"),
    				showName: true});
    	}
    });

	var AssignmentInfoView = Backbone.View.extend({

		render: function(){

		}
	});

	return AssignmentCalendarView;
});
