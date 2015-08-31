/**
 * This is a base class for a calendar view.  This should be extended (subclassed) to use. 
 *
 *  options:
 *     calendarType: "month" or "week"  to display a full month or week (which is two weeks)
 */ 

define(['backbone', 'underscore','views/MainView', 'moment','jquery-truncate','bootstrap'], 
    function(Backbone, _,MainView, moment) {
	
    var CalendarView = Backbone.View.extend({
        className: "calendar",
        initialize: function (options){
            var self = this;
            _.bindAll(this, 'render','showWeekView','showMonthView','viewPreviousWeek','viewNextWeek');
            
            var defaults = {num_of_weeks: 6, first_day: ""};
            this.state = new Backbone.Model(_.extend({},defaults,_(options).pick("num_of_weeks","first_day")));
            
            if (! this.date){
                this.date = moment();  // today!
            }
            this.state.on("change:first_day",function(){
                self.trigger("calendar-change");
            });

            this.weekViews = []; // array of CalendarWeekViews
            return this;
        },
        render: function () {
            var self = this;            

            this.weekViews = [];
            for(var i = 0; i<this.state.get("num_of_weeks"); i++){
                this.weekViews[i] = new WeekView({first_day: moment(this.state.get("first_day")).add(7*i,"days"),
                    calendar: this});
            }
            

            this.$el.html($("#calendar-template").html());
            var calendarHead = this.$("#calendar-table thead");
            for(var i = 0; i<7; i++){
                var day = moment().day(i);
                calendarHead.append("<th>" + day.format("dddd") + "</th>");
            }
            var calendarTable = this.$('#calendar-table tbody');

            _(this.weekViews).each(function(_week){
                calendarTable.append(_week.render().el);
            });                        
            this.$(".month-name").text(moment(this.firstDay).format("MMMM YYYY"));
            //this.$el.append(calendarTable.el);
            //this.delegateEvents(this.events());
            return this;   
        },
        events: function () {
          return this.calendarChangeEvents;  
        },
        calendarChangeEvents: { 
            "click .previous-week": "viewPreviousWeek",
            "click .next-week": "viewNextWeek",
            "click .view-week": "showWeekView",
            "click .view-month": "showMonthView",
            "click .goto-today": "gotoToday"
        },
        viewPreviousWeek: function (){
            this.state.set("first_day",moment(this.state.get("first_day")).subtract(7,"days").format("YYYY-MM-DD"));
            this.render();
            this.trigger("calendar-change");
        },
        viewNextWeek: function() {
            this.state.set("first_day",moment(this.state.get("first_day")).add(7,"days").format("YYYY-MM-DD"));
            this.render();
            this.trigger("calendar-change");
        },
        showWeekView: function () {
            this.state.set("num_of_weeks",2);
            this.render();
        },
        showMonthView: function () {
            this.state.set("num_of_weeks",6);
            this.render();
        }, 
        gotoToday: function () {
            var firstOfMonth = moment().date(1);
            var firstDay = this.state.get("calendar_type")==="month"?
                moment(firstOfMonth).date(1).subtract(firstOfMonth.date(1).day(),"days"):
                moment().subtract(moment().day(),"days");
            this.state.set("first_day",firstDay);
        },
        renderDay: function(){
            // this is called from the CalendarDayView.render() to be useful, this should be overridden in the subclass
        },
        set: function(options){
            this.state.set(_(options).pick("num_of_weeks","first_day"));
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
                this.days[i] = new DayView({model: moment(this.first_day).add(i,"days"),
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
            if (this.calendar.calendar_type==="month"){
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
            if (this.calendar.calendar_type==="week") {
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