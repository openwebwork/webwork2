/**
  * This is the assignment calendar view. 
  *
  */


define(['backbone', 'underscore', 'moment','views/MainView', 'views/CalendarView','config'], 
    function(Backbone, _, moment,MainView, CalendarView,config) {
	
    var AssignmentCalendar = CalendarView.extend({
    	template: _.template(this.$("#calendar-date-bar").html()),
        popupTemplate: _.template(this.$("#calendar-date-popup-bar").html()),
        headerInfo: {template: "#calendar-header", events: 
                { "click .previous-week": "viewPreviousWeek",
                    "click .next-week": "viewNextWeek",
                    "click .view-week": "showWeekView",
                    "click .view-month": "showMonthView"}
        },
    	initialize: function (options) {
            var self = this;
            CalendarView.prototype.initialize.call(this,options);
    		_.bindAll(this,"render","renderDay","update");

            this.problemSets.on({sync: this.render});
            return this;
    	},
    	render: function (){
    		this.constructor.__super__.render.apply(this);
            this.update();

    		this.$(".assign").popover({html: true});
            this.$(".assign").truncate({width: 100});
            // set up the calendar to scroll correctly
            this.$(".calendar-container").height($(window).height()-160);
            MainView.prototype.render.apply(this);
            return this;
    	},
    	renderDay: function (day){
    		var self = this;
            var assignments = this.assignmentDates.where({date: day.model.format("YYYY-MM-DD")});
            _(assignments).each(function(assign){
                var popup = this.$(self.template({classes: "assign assign-" + assign.get("type"), 
                    setname: assign.get("problemSet").get("set_id"), showName: true}));
                popup.attr("data-content",self.popupTemplate(_.extend({},assign.get("problemSet"),
                    {totalUsers: self.users.length})));

                day.$el.append(popup);
            });
    	},
        getHelpTemplate: function (){
            return $("#calendar-help-template").html();
        },
        // perhaps this should go in the MainView class
        set: function (options) {
            CalendarView.prototype.set.call(this,options);
            return this;
        },
        getState: function () {
            return {};
        },
        update:  function (){
            var self = this;
            // The following allows each day in the calendar to allow a problem set to be dropped on. 
                 
            this.$(".calendar-day").droppable({
                hoverClass: "highlight-day",
                accept: ".problem-set, .assign",
                greedy: true,
                drop: function(ev,ui) {
                    ev.stopPropagation();
                    if($(ui.draggable).hasClass("problem-set")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"all");
                    } else if ($(ui.draggable).hasClass("assign-open")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"open_date");
                    } else if ($(ui.draggable).hasClass("assign-due")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"due_date");
                    } else if ($(ui.draggable).hasClass("assign-answer")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"answer_date");
                    }

                }
            });

            // The following allows an assignment date (due, open) to be dropped on the calendar

            this.$(".assign-due,.assign-open,.assign-answer").draggable({
                revert: true,
                start: function () {$(this).popover("destroy")}
            });
        },
        setDate: function(_setName,_date,type){  // sets the date in the form YYYY-MM-DD
            var problemSet = this.problemSets.findWhere({set_id: _setName.toString()});
            if(type==="all") {
                problemSet.setDefaultDates(_date).save({success: this.update()});
            } else {
                problemSet.setDate(type,moment(_date,"YYYY-MM-DD").unix());
            }

        }

    });

	return AssignmentCalendar;
});
