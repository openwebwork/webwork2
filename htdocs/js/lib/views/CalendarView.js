/**
 * This is a base class for a calendar view.  This should be extended (subclassed) to use. 
 *
 *  options:
 *     calendarType: "month" or "week"  to display a full month or week (which is two weeks)
 */ 

define(['Backbone', 'underscore', 'moment','views/Closeable','jquery-truncate','bootstrap'], 
    function(Backbone, _, moment,Closeable) {
	
    var CalendarView = Backbone.View.extend({
        className: "calendar",
        initialize: function (){
            _.bindAll(this, 'render','showWeekView','showMonthView','viewPreviousWeek','viewNextWeek');  // include all functions that need the this object
    	    this.dispatcher = _.clone(Backbone.Events);  // include a dispatch to manage calendar changes. 
        
            this.calendarType = this.options.calendarType;

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
                calendarTable.append((new CalendarRowView({week: _week, calendar: self})).el);
            });                        
        
            this.$el.append(calendarTable.el);

            this.dispatcher.trigger("calendar-change");
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
        }
    });

    var CalendarRowView = Backbone.View.extend({  // This displays a row of the Calendar
        tagName: "tr",
        className: "calendar-row",
        initialize: function (){
            _.bindAll(this, 'render');  // include all functions that need the this object
            _.extend(this,this.options);

            this.render();
            return this; 
        },
        render: function () {
            var self = this;
            _(this.week).each(function(date) {
                var calendarDay = new CalendarDayView({model: date, calendar: self.calendar});
                self.$el.append(calendarDay.el);
            });

            return this;
            }
    });

    var CalendarDayView = Backbone.View.extend({ // This displays a day in the Calendar
        tagName: "td",
        className: "calendar-day",
        initialize: function (){
            _.bindAll(this, 'render');  // include all functions that need the this object
            var self = this;
            this.calendar = this.options.calendar;

            this.today = moment();
            this.render();
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