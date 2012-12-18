define(['Backbone', 'underscore', './CalendarDayView'], function(Backbone, _, CalendarDayView){
	CalendarRowView = Backbone.View.extend({  // This displays a row of the Calendar
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
    return CalendarRowView
});