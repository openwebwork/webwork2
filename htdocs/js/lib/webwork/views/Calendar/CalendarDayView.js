define(['Backbone', 'underscore', 'XDate'], function(Backbone, _, XDate){
	CalendarDayView = Backbone.View.extend({ // This displays a day in the Calendar
        tagName: "td",
        className: "calendar-day",
        initialize: function (){
            _.bindAll(this, 'render','showAssignments');  // include all functions that need the this object
	    var self = this;

	    this.today = XDate.today();
	    _.extend(this,this.options);
            this.render();
            return this;
        },
        render: function () {
            var self = this;
            var str = "";
            if (this.calendar.viewType==="month"){
            	str = (this.model.getDate()==1)? this.model.toString("MMM dd") : this.model.toString("dd");
            } else {
            	str = this.model.toString("MMM dd");
            }
            this.$el.html(str);
            this.$el.attr("id","date-" + this.model.toString("yyyy-MM-dd"));
            if (this.calendar.date.getMonth()===this.model.getMonth()){this.$el.addClass("this-month");}
            if (this.today.diffDays(this.model)===0){this.$el.addClass("today");}
            if (this.calendar.viewType==="week") {this.$el.addClass("week-view");} else {this.$el.addClass("month-view");}
	    

            self.showAssignments();

		    return this;
        },
        showAssignments: function () {
        	var self = this;
    	    _(this.calendar.timeSlot).each(function (slot){
	        	var slotFilled = false; 
	        	_(slot).each(function(problemSet){
					if (problemSet.isDueOn(self.model,3*24*60)){
				    	self.$el.append("<div class='assign assign-open assign-set-name' data-set='" + problemSet.get("set_id") + "'><span> " 
				    					+ problemSet.get("set_id") + "</span></div>");
				    	slotFilled = true; 
				    }
					else if (problemSet.isOpen(self.model,3*24*60))  {
						self.$el.append("<div class='assign assign-open assign-set-name' data-set='" + problemSet.get("set_id")+ "'></div>");
						slotFilled = true; 	
					} else if (problemSet.isInReducedCredit(self.model,3*24*60)) {
						self.$el.append("<div class='assign assign-reduced-credit' data-set='" + problemSet.get("set_id")+ "'></div>");
						slotFilled = true; 
					} 
				});
				if (!slotFilled) {self.$el.append("<div class='assign empty'></div>");}
	        });

        }
    });

	return CalendarDayView
});