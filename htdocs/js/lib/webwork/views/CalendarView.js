define(['Backbone', 'underscore', 'XDate','Closeable','jquery-truncate','bootstrap'], 
    function(Backbone, _, XDate,Closeable) {
	
    var CalendarView = Backbone.View.extend({
        tagName: "div",
        className: "calendar",
        initialize: function (){
            _.bindAll(this, 'render','updateAssignments');  // include all functions that need the this object
    	    var self = this;
            
            /* Clean this up.  what is the difference between theDate and this.options.date
            *  probably _.extend(this,this.options) will suffice.
            */

            var theDate = this.date;

            _.extend(this, this.options);
            this.viewType = (this.options.viewType)? (this.options.viewType): "month";  // viewType is either "month" or "week"
            

            if (! theDate) { theDate = new XDate();}

            // For the calendar, ignore the time part of the date object.

            this.date = new XDate(theDate.getFullYear(),theDate.getMonth(),theDate.getDate());  
            
            var firstOfMonth = new XDate(this.date.getFullYear(),this.date.getMonth(),1);

            if (this.viewType === "month"){
               this.firstDayOfCalendar = firstOfMonth.clone().addDays(-1*firstOfMonth.getDay());  
            } else {
                this.firstDayOfCalendar = this.date.clone().addDays(-1*this.date.getDay());
            }


            this.updateAssignments();

            this.render();

             if ((this.timeSlot.length>5) && (this.viewType === "month")) {
                this.errorBar.appendHTML($("#too-many-assignments-error").html());
            }
           
            return this;


        },               // This needs to determine the visual bars on the calendar. 
        updateAssignments: function() 
        {
            //console.log("in updateAssignments");
            var sets = this.collection.sortBy(function (_set) { return new XDate(_set.get("open_date"))});
            

            var n = 0; 
            var slot = [];
            slot[0]=[];
            while (sets.length>0){
                var s = sets.pop();
                var k = 0; 
                var foundSlot = false; 
                while(slot[k].length > 0){
                    if (!(_(slot[k]).any(function (_set) { return s.overlaps(_set)}))) {
                        foundSlot = true;
                        slot[k].push(s);
                        break;
                    } 
                    k++;
                }
                if (!foundSlot){
                   slot[k].push(s);
                   slot[k+1] = [];
                    n++;
                }
                /* _(slot).each(function(set,i){
                    console.log(i + " " + _(set).map(function(s){return s.get("set_id")}));
                }); */

            }    
            slot.pop();  // there's always an empty array at the end. 

            this.timeSlot = slot;


            
        },
        render: function () {
            var self = this;
            // The collection is a array of rows containing the day of the current month.
            
            this.$el.html(_.template($("#calendar-template").html()));
            var calendarTable = this.$('#calendar-table');
            this.errorBar = new Closeable({el : $("#calendar-error-bar"), classes: ["alert-error"]});
                        
            if (this.viewType === "month"){            
                for(var i = 0; i<6; i++){ var theWeek = [];
                    for(var j = 0; j < 7; j++){
                     theWeek.push(this.firstDayOfCalendar.clone().addDays(j+7*i));
                    }
                    var calendarWeek = new CalendarRowView({week: theWeek, calendar: this});
                    calendarTable.append(calendarWeek.el);                
                }
            } else {
                var theWeek = [];

                for(var j = 0; j < 7; j++){
                    theWeek.push(this.firstDayOfCalendar.clone().addDays(j));
                }
                var calendarWeek = new CalendarRowView({week: theWeek, calendar: this});
                calendarTable.append(calendarWeek.el);                
            }

                    // The following adds buttons for the go ahead and back by two weeks.  

        
        this.$el.append(calendarTable.el);
        //this.$el.append(_.template($("#calendarButtons").html()));
        $(".previous-week").on("click", function () {
            self.date.addDays(-7); 
            self.firstDayOfCalendar.addDays(-7); 
            self.update();
        });

        $(".next-week").on("click", function () {
            self.date.addDays(7); 
            self.firstDayOfCalendar.addDays(7); 
            self.update();
        });

        $(".view-week").on("click",function() {
            self.viewType = "week";
            self.update(); 
        });
        $(".view-month").on("click",function() {
            self.viewType = "month";
            self.update(); 
        });

        var dayWidth = parseInt($("#calendar-table").width()/7)-20;
        $(".assign-open").truncate({width: dayWidth});
        $(".assign-reduced-credit").truncate({width: dayWidth});

        if (this.view === "student"){
            $(".assign-open,.assign-reduced-credit").attr("data-content","");
        } 
        $(".assign-open,.assign-reduced-credit").popover({placement: "top", html: true});

        return this;   
    },
    update: function ()
    {
        this.render();
        this.parent.dispatcher.trigger("calendar-change");
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

            var threeDays = 3*24*60; // Why is this hard coded? 
            var self = this;
            if ((this.calendar.viewType === "week") || (this.calendar.timeSlot.length<6)) {
                _(this.calendar.timeSlot).each(function (slot){
                    var slotFilled = false; 
                    _(slot).each(function(problemSet){
                        var props = (self.calendar.view==="student")? 
                                {setname: problemSet.get("set_id"),assignedUsers:"",totalUsers:"", openToStudents:""}:
                                {setname: problemSet.get("set_id"), assignedUsers: problemSet.assignedUsers.length, 
                                totalUsers: self.calendar.parent.users.size(), 
                                openToStudents: problemSet.get("visible"), showName: false};
                        if (problemSet.isDueOn(self.model,threeDays)){
                            self.$el.append(_.template($("#calendar-date-bar").html(),
                                _.extend(props, {classes : "assign assign-set-name assign-open", showName: true}))); 
                            slotFilled = true; 
                        }
                        else if (problemSet.isOpen(self.model,threeDays))  {
                            self.$el.append(_.template($("#calendar-date-bar").html(),
                                _.extend(props, {classes : "assign assign-open", showName: false}))); 
                            slotFilled = true;  
                        } else if (problemSet.isInReducedCredit(self.model,threeDays)) {
                            self.$el.append(_.template($("#calendar-date-bar").html(),
                                _.extend(props, {classes : "assign assign-reduced-credit", showName: false}))); 
                            slotFilled = true; 
                        } 
                    });
                    if (!slotFilled) {self.$el.append("<div class='assign empty'></div>");}
                });
            } else {
                self.$el.append("<div class='assign assign-filled'></div>");
                // denote that more than five assignments overlap. 
            }
        }
    });


	return CalendarView;
});