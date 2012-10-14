define(['Backbone', 'underscore', 'XDate', './CalendarRowView'], function(Backbone, _, XDate, CalendarRowView) {
	CalendarView = Backbone.View.extend({
        tagName: "table",
        className: "calendar",
        initialize: function (){
            _.bindAll(this, 'render');  // include all functions that need the this object
	    var self = this;
            var theDate = this.date;; 
            if (this.options.date) {theDate = this.options.date;}

            if (! theDate) { theDate = new XDate();}
            this.date = new XDate(theDate.getFullYear(),theDate.getMonth(),theDate.getDate());  // For the calendar, ignore the time part of the date object.
            
            this.render();
            return this;
            
        },
        render: function () {
            // The collection is a array of rows containing the day of the current month.
            
            
            var firstOfMonth = new XDate(this.date.getFullYear(),this.date.getMonth(),1);
            var firstWeekOfMonth = firstOfMonth.clone().addDays(-1*firstOfMonth.getDay());
            
            this.$el.html(_.template($("#calendarHeader").html()));
                        
            for(var i = 0; i<6; i++){ var theWeek = [];
                for(var j = 0; j < 7; j++){
                 theWeek.push(firstWeekOfMonth.clone().addDays(j+7*i));
                }
                var calendarWeek = new CalendarRowView({week: theWeek, calendar: this});
                this.$el.append(calendarWeek.el);                
            }
            return this;   
        }
    });
	return CalendarView;
});