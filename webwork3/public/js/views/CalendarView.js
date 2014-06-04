/**
 * This is a base class for a calendar view.  This should be extended (subclassed) to use. 
 *
 *  options:
 *     calendarType: "month" or "week"  to display a full month or week (which is two weeks)
 */ 

define(['backbone', 'underscore','views/MainView', 'moment','jquery-truncate','bootstrap'], 
    function(Backbone, _,MainView, moment) {
	
    var CalendarView = MainView.extend({
        className: "calendar",
        initialize: function (options){
            MainView.prototype.initialize.call(this,options);
            //this.constructor.__super__.constructor.__super__.initialize.apply(this, options);
            _.bindAll(this, 'render','showWeekView','showMonthView','viewPreviousWeek','viewNextWeek');  // include all functions that need the this object
    	    this.dispatcher = _.clone(Backbone.Events);  // include a dispatch to manage calendar changes. 
        
            this.calendarType = options.calendarType || "month";

            if (! this.date){
                this.date = moment();  // today!
            }

            // build up the initial calendar.  

            var firstOfMonth = moment(this.date).date(1);
            var firstDayOfCalendar = (this.calendarType==="month")?
                    moment(firstOfMonth).date(1).add("days",-1*firstOfMonth.date(1).day()):
                    moment(this.date).add("days",-1*firstOfMonth.day());

            this.createCalendar(firstDayOfCalendar,(this.calendarType==="month")?6:2);  // instead of hard coding this make these parameters. 
            
            return this;
        },
        createCalendar: function(firstDayOfCalendar,numberOfWeeks){
            var theWeek = [];
            this.weeks = [];
            
            for(var i = 0; i<numberOfWeeks; i++){
                theWeek = [];
                for(var j = 0; j < 7; j++){
                 theWeek.push(moment(firstDayOfCalendar).add("days",j+7*i));
                }
                this.weeks.push(theWeek);
            }
        },
        render: function () {
            var self = this;
            // The collection is a array of rows containing the day of the current month.
            

            this.$el.html(_.template($("#calendar-template").html()));
            var calendarHead = this.$("#calendar-table thead");
            for(var i = 0; i<7; i++){
                var day = moment().day(i);
                calendarHead.append("<th>" + day.format("dddd") + "</th>");
            }
            var calendarTable = this.$('#calendar-table tbody');

            _(this.weeks).each(function(_week){
                calendarTable.append((new CalendarRowView({week: _week, calendar: self})).render().el);
            });                        
            this.$(".month-name").text(this.weeks[0][0].format("MMMM YYYY"));
            this.$el.append(calendarTable.el);
            return this;   
        },
        events: {"click .previous-week": "viewPreviousWeek",
            "click .next-week": "viewNextWeek",
            "click .view-week": "showWeekView",
            "click .view-month": "showMonthView"},
        viewPreviousWeek: function (){
            var firstDate = moment(this.weeks[0][0]).subtract("days",7)
              , theWeek = [];
            for(var i=0;i<7;i++){
                theWeek.push(moment(firstDate).add("days",i));
            }
            this.weeks.splice(0,0,theWeek);
            this.weeks.pop();
            this.render();
            this.dispatcher.trigger("calendar-change");
        },
        viewNextWeek: function() {
            var lastDate = moment(this.weeks[this.weeks.length-1][0]).add("days",7)
              , theWeek = [];
            for(var i=0;i<7;i++){
                theWeek.push(moment(lastDate).add("days",i));
            }
            this.weeks.splice(0,1);
            this.weeks.push(theWeek);
            this.render();
            this.dispatcher.trigger("calendar-change");
        },
        showWeekView: function () {
            this.calendarType="week";
            if (this.weeks.length===2) {return;}
            var today = moment();
            this.createCalendar(today.subtract("days",today.day()),2);
            this.render();
            this.dispatcher.trigger("calendar-change");
        },
        showMonthView: function () {
            if(this.weeks.length===6){return;}
            this.calendarType = "month";
            this.createCalendar(moment(this.weeks[0][0]).subtract("days",14),6);            
            this.render();
            this.dispatcher.trigger("calendar-change");
        }, 
        renderDay: function(){
            // this is called from the CalendarDayView.render() to be useful, this should be overridden in the subclass
        },
        set: function(options){
            this.assignmentDates = options.assignmentDates;
            this.viewType = options.viewType;
            this.reducedScoringMinutes = options.reducedScoringMinutes;
            return this;
        }
    });

    var CalendarRowView = Backbone.View.extend({  // This displays a row of the Calendar
        tagName: "tr",
        className: "calendar-row",
        initialize: function (options){
            _.bindAll(this, 'render');  // include all functions that need the this object
            this.week = options.week;
            this.calendar = options.calendar;
        },
        render: function () {
            var self = this;
            _(this.week).each(function(date) {
                var calendarDay = new CalendarDayView({model: date, calendar: self.calendar});
                self.$el.append(calendarDay.render().el);
            });

            return this;
            }
    });

    var CalendarDayView = Backbone.View.extend({ // This displays a day in the Calendar
        tagName: "td",
        className: "calendar-day",
        initialize: function (options){
            _.bindAll(this, 'render');  // include all functions that need the this object
            var self = this;
            this.calendar = options.calendar;
            this.today = moment();
            return this;
        },
        render: function () {
            var self = this;
            var str = "";
            if (this.calendar.calendarType==="month"){
                str = (this.model.date()==1)? this.model.format("MMM D") : this.model.format("D");
            } else {
                str = this.model.format("MMM D");
            }
            this.$el.html(str);
            this.$el.attr("data-date",this.model.format("YYYY-MM-DD"));
            if (this.calendar.date.month()===this.model.month()){
                this.$el.addClass("this-month");
            }
            if (this.today.isSame(this.model,"day")){
                this.$el.addClass("today");
            }
            if (this.calendar.calendarType==="week") {
                this.$el.addClass("week-view");
            } else {
                this.$el.addClass("month-view");
            }

            this.calendar.renderDay(this);

            return this;
        }
    });

	return CalendarView;
});