define(['Backbone', 'underscore', 'XDate','Closeable','jquery-truncate','bootstrap'], 
    function(Backbone, _, XDate,Closeable) {
	
    var CalendarView = Backbone.View.extend({
        tagName: "div",
        className: "calendar",
        initialize: function (){
            _.bindAll(this, 'render','updateAssignments','showWeekView','showMonthView','viewPreviousWeek',
                        'viewNextWeek');  // include all functions that need the this object
    	    _.extend(this, this.options);
        
            if (! this.date){
                this.date = XDate.today();
            }
        
            this.updateAssignments();
            this.reducedScoringMinutes = this.parent.settings.find(function(setting) { return setting.get("var")==="pg{ansEvalDefaults}{reducedScoringPeriod}";}).get("value");

            if ((this.timeSlot.length>5) && (this.viewType === "month")) {
                this.parent.errorPane.addMessage({text: $("#too-many-assignments-error").html()});
                this.viewType = "week";
            }

            // build up the initial calendar.  

            var firstOfMonth = new XDate(this.date.getFullYear(),this.date.getMonth(),1);
            var firstDayOfCalendar = (this.viewType==="month")?firstOfMonth.clone().addDays(-1*firstOfMonth.getDay()):
                    this.date.clone().addDays(-1*this.date.getDay());

            this.createCalendar(firstDayOfCalendar,(this.viewType==="month")?6:2);

            this.render();
            return this;
        },
        createCalendar: function(firstDayOfCalendar,numberOfWeeks){
            var theWeek = [];
            this.weeks = [];
            
            for(var i = 0; i<numberOfWeeks; i++){
                theWeek = [];
                for(var j = 0; j < 7; j++){
                 theWeek.push(firstDayOfCalendar.clone().addDays(j+7*i));
                }
                this.weeks.push(theWeek);
            }

        },
        render: function () {
            var self = this;
            // The collection is a array of rows containing the day of the current month.
            

            this.$el.html(_.template($("#calendar-template").html()));
            var calendarTable = this.$('#calendar-table');

            _(this.weeks).each(function(_week){
                calendarTable.append((new CalendarRowView({week: _week, calendar: self})).el);
            });                        
        
            this.$el.append(calendarTable.el);

            var dayWidth = parseInt($("#calendar-table").width()/7)-20;
            $(".assign-open").truncate({width: dayWidth});
            $(".assign-reduced-credit").truncate({width: dayWidth});

            if (this.view === "student"){
                $(".assign-open,.assign-reduced-credit,.assign-not-visible").attr("data-content","");
            } 
            $(".assign-open,.assign-reduced-credit,.assign-not-visible").popover({placement: "top", html: true});

            return this;   
        },
        events: {"click .previous-week": "viewPreviousWeek",
            "click .next-week": "viewNextWeek",
            "click .view-week": "showWeekView",
            "click .view-month": "showMonthView"},
        viewPreviousWeek: function (){
            var firstDate = this.weeks[0][0].clone().addDays(-7)
              , theWeek = [];
            for(var i=0;i<7;i++){
                theWeek.push(firstDate.clone().addDays(i));
            }
            this.weeks.splice(0,0,theWeek);
            this.weeks.pop();
            this.render();
            this.parent.dispatcher.trigger("calendar-change");
        },
        viewNextWeek: function() {
            var lastDate = this.weeks[this.weeks.length-1][0].clone().addDays(7)
              , theWeek = [];
            for(var i=0;i<7;i++){
                theWeek.push(lastDate.clone().addDays(i));
            }
            this.weeks.splice(0,1);
            this.weeks.push(theWeek);
            this.render();
            this.parent.dispatcher.trigger("calendar-change");
        },
        showWeekView: function () {
            this.viewType="week";
            if (this.weeks.length===2) {return;}
            var today = XDate.today();
            this.createCalendar(today.addDays(-1*today.getDay()),2);
            this.render();
            this.parent.dispatcher.trigger("calendar-change");
        },
        showMonthView: function () {
            if(this.weeks.length===6){return;}
            this.viewType = "month";
            this.createCalendar(this.weeks[0][0].clone().addDays(-14),6);            
            this.render();
            this.parent.dispatcher.trigger("calendar-change");
        },              // This needs to determine the visual bars on the calendar. 
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
        template: _.template($("#calendar-date-bar").html()),
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

            // pstaabp:  This is a mess.  Let's try to find a better way to do this.              

            if ((this.calendar.viewType === "week") || (this.calendar.timeSlot.length<6)) {
                _(this.calendar.timeSlot).each(function (slot){
                    var slotFilled = false; 
                    _(slot).each(function(problemSet){
                        var props = (self.calendar.view==="student")? 
                            {setname: problemSet.get("set_id"),assignedUsers:"",totalUsers:"", openToStudents:""}:
                            {setname: problemSet.get("set_id"), assignedUsers: problemSet.assignedUsers.length, 
                            totalUsers: self.calendar.parent.users.size(), 
                            openToStudents: problemSet.get("visible"), showName: false};
                        if (problemSet.get("visible")==="no"){
                            if (problemSet.isDueOn(self.model,0)){
                                self.$el.append(self.template(_.extend(props, 
                                    {classes : "assign assign-set-name assign-not-visible", showName: true}))); 
                                slotFilled = true; 
                            } else if (problemSet.isOpen(self.model,0)){
                                self.$el.append(self.template(_.extend(props, 
                                    {classes : "assign assign-not-visible", showName: false}))); 
                                slotFilled = true; 
                            }
                            

                        }
                        else if (problemSet.isDueOn(self.model,self.calendar.reducedScoringMinutes)){
                            self.$el.append(self.template(_.extend(props,{classes : "assign assign-set-name assign-open", showName: true}))); 
                            slotFilled = true; 
                        }
                        else if (problemSet.isOpen(self.model,self.calendar.reducedScoringMinutes))  {
                            self.$el.append(self.template(_.extend(props, {classes : "assign assign-open", showName: false}))); 
                            slotFilled = true;  
                        } else if (problemSet.isInReducedCredit(self.model,self.calendar.reducedScoringMinutes)) {
                            self.$el.append(self.template(_.extend(props,  {classes : "assign assign-reduced-credit", showName: false}))); 
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