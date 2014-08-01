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
            _.bindAll(this, 'render','showWeekView','showMonthView','viewPreviousWeek','viewNextWeek');  // include all functions that need the this object
    	    
            if (! this.date){
                this.date = moment();  // today!
            }

            this.weekViews = []; // array of CalendarWeekViews
            return this;
        },
        render: function () {
            var self = this;            

            // remove any popups that exist already.  
            this.$(".show-set-popup-info").popover("destroy")

            var numberOfWeeks = this.state.get("calendar_type")==="month"? 6 : 2; 
            this.weekViews = [];
            for(var i = 0; i<numberOfWeeks; i++){
                this.weekViews[i] = new WeekView({first_day: moment(this.state.get("first_day")).add("days",7*i),
                    calendar: this});
            }
            

            this.$el.html(_.template($("#calendar-template").html()));
            var calendarHead = this.$("#calendar-table thead");
            for(var i = 0; i<7; i++){
                var day = moment().day(i);
                calendarHead.append("<th>" + day.format("dddd") + "</th>");
            }
            var calendarTable = this.$('#calendar-table tbody');

            _(this.weekViews).each(function(_week){
                calendarTable.append(_week.render().el);
            });                        
            this.$(".month-name").text(moment(this.state.get("first_day")).format("MMMM YYYY"));
            this.$el.append(calendarTable.el);
            return this;   
        },
        events: {"click .previous-week": "viewPreviousWeek",
            "click .next-week": "viewNextWeek",
            "click .view-week": "showWeekView",
            "click .view-month": "showMonthView",
            "click .goto-today": "gotoToday"
        },
        getDefaultState: function () {
            var firstOfMonth = moment(this.date||moment()).date(1)
                , firstDay = moment(firstOfMonth).subtract("days",firstOfMonth.date(1).day());
            return {
                answer_date: true,
                due_date: true,
                reduced_scoring_date: true,
                open_date: true,
                first_day: firstDay.format("YYYY-MM-DD"),
                calendar_type: "month"
            };
        },
        viewPreviousWeek: function (){
            this.state.set("first_day",moment(this.state.get("first_day")).subtract("days",7).format("YYYY-MM-DD"));
        },
        viewNextWeek: function() {
            this.state.set("first_day",moment(this.state.get("first_day")).add("days",7).format("YYYY-MM-DD"));
        },
        showWeekView: function () {
            this.state.set("calendar_type","week");
        },
        showMonthView: function () {
            this.state.set("calendar_type","month");
        }, 
        gotoToday: function () {
            var firstOfMonth = moment().date(1);
            var firstDay = this.state.get("calendar_type")==="month"?
                moment(firstOfMonth).date(1).subtract("days",firstOfMonth.date(1).day()):
                moment().subtract("days",moment().day());
            this.state.set("first_day",firstDay);
            this.trigger("calendar-change");
        },
        renderDay: function(){
            // this is called from the CalendarDayView.render() to be useful, this should be overridden in the subclass
        },
        set: function(options){
            _(this).extend(_(options).pick("assignmentDates","viewType","reducedScoringMinutes","first_day"));
            return this;
        }
    });

    var WeekView = Backbone.View.extend({  // This displays a row of the Calendar
        tagName: "tr",
        className: "calendar-row",
        initialize: function (options){
            this.first_day = options.first_day;  // the first day of the week.  
            this.days = []; // an array of DayViews;
            var i;
            for(i=0;i<7;i++){
                this.days[i] = new DayView({model: moment(this.first_day).add("days",i),
                    calendar: options.calendar});
            }
        },
        render: function () {
            var self = this;
            _(this.days).each(function(day) {
                self.$el.append(day.render().el);
            });
            return this;
        }
    });

    var DayView = Backbone.View.extend({ // This displays a day in the Calendar
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
            if (Math.abs(this.model.month()-this.calendar.date.month()) %2 == 0){
                this.$el.addClass("this-month");
            } else {
                this.$el.addClass("that-month");
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