/**
  * This is the assignment calendar view. 
  *
  */


define(['Backbone', 'underscore', 'moment','views/CalendarView','config'], 
    function(Backbone, _, moment,CalendarView,config) {
	
    var StudentCalendarView = CalendarView.extend({
    	template: _.template($("#calendar-date-bar").html()),
        initialize: function (options) {
            var self = this;
    		this.constructor.__super__.initialize.apply(this, [_.extend({el: this.el},options)]);
    		_.bindAll(this,"render","renderDay");

    		this.assignmentDates = options.assignmentDates;
            this.userSets = options.userSets; 

    		this.reducedScoringMinutes = options.reducedScoringMinutes;
        //    _.extend(this.events,this.headerInfo.events);
    	},
    	render: function (){
    		this.constructor.__super__.render.apply(this);
            this.$(".calendar-header").html($("#calendar-header").html());
    		this.$(".assign").popover({html: true});
            this.$(".assign").truncate({width: 100});
            // set up the calendar to scroll correctly
            this.$(".calendar-container").height($(window).height()-100);
    	},
    	renderDay: function (day){
    		var self = this;
            var assignments = this.assignmentDates.where({date: day.model.format("YYYY-MM-DD")});
            _(assignments).each(function(assign){
                day.$el.append(self.template({classes: "assign assign-" + assign.get("type"), 
                    setname: assign.get("problemSet").get("set_id"), 
                }));
            });
    	},
        events: {"click button.goto-set-button": "gotoSet",
                    "click .previous-week": "viewPreviousWeek",
                    "click .next-week": "viewNextWeek",
                    "click .view-week": "showWeekView",
                    "click .view-month": "showMonthView"
        },
        gotoSet: function(evt){
            var _set = this.userSets.findWhere({set_id: $(evt.target).data("setname")})
            _set.trigger("showSet",_set);
        }
    });

	return StudentCalendarView;
});
