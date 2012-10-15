define(['Backbone', 'underscore', 'XDate'], function(Backbone, _, XDate){
	CalendarDayView = Backbone.View.extend({ // This displays a day in the Calendar
        tagName: "td",
        className: "calendar-day",
        initialize: function (){
            _.bindAll(this, 'render');  // include all functions that need the this object
	    var self = this;
	    _.extend(this,this.options);
            this.render();
            return this;
        },
        render: function () {
            var self = this;
            var str = (this.model.getDate()==1)? this.model.toString("MMM dd") : this.model.toString("dd");
            this.$el.html(str);
            this.$el.attr("id","date-" + this.model.toString("yyyy-MM-dd"));
            if (this.calendar.date.getMonth()===this.model.getMonth()){this.$el.addClass("this-month");}
            if (this.calendar.date.diffDays(this.model)===0){this.$el.addClass("today");}
	    
	    var set = this.calendar.collection.find(function (model) { return model.get("set_id")==="Demo"});
	    
	    var openDate = new XDate(set.get("open_date"));
	    var dueDate = new XDate(set.get("due_date"));
	    if ((openDate.diffDays(this.model)>=0) && (dueDate.diffDays(this.model)<=0))
	    {
		if ((this.model.diffDays(dueDate)<3) && (this.model.diffDays(dueDate) >2))  // This is hard-coded.  We need to lookup the reduced credit time.  
		{
			this.$el.append("<div class='assign assign-open assign-set-name'> <span class='pop' data-content='test' rel='popover'>Demo</span></div>");
			
		} else
		if (Math.abs(this.model.diffDays(dueDate))<3)
		{
			this.$el.append("<div class='assign assign-reduced-credit'></div>");
		} else
		{
			this.$el.append("<div class='assign assign-open'></div>");
		}
		
		
	    }
	            return this;
        }
    });

	return CalendarDayView
});