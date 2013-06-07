/**
  * This is the assignment calendar view. 
  *
  */


define(['Backbone', 'underscore', 'moment','./CalendarView','config'], 
    function(Backbone, _, moment,CalendarView,config) {
	
    var AssignmentCalendarView = CalendarView.extend({
    	template: _.template($("#calendar-date-bar").html()),
    	initialize: function () {
    		this.constructor.__super__.initialize.apply(this, {el: this.el});
    		_.bindAll(this,"render","renderDay","createAssignInfoBar");

    		this.problemSets = this.options.problemSets; 

    		this.reducedScoringMinutes = this.options.reducedScoringMinutes;
            /*this.updateAssignments();
            this.reducedScoringMinutes = this.parent.settings.find(function(setting) { return setting.get("var")==="pg{ansEvalDefaults}{reducedScoringPeriod}";}).get("value");

            if ((this.timeSlot.length>5) && (this.viewType === "month")) {
                this.parent.errorPane.addMessage({ text: $("#too-many-assignments-error").html()});
                this.viewType = "week";
            } */


    	},
    	render: function (){
    		this.constructor.__super__.render.apply(this);

    		this.$(".assign").popover({html: true});
    	},
    	renderDay: function (day){
    		var self = this;
    		this.problemSets.each(function(assign){
    			if(config.parseWWDate(assign.get("due_date")).date.isSame(day.model,"day")){
    				day.$el.append(self.createAssignInfoBar(assign,"assign assign-due"));
    			}
    			if(config.parseWWDate(assign.get("open_date")).date.isSame(day.model,"day")){
    				day.$el.append(self.createAssignInfoBar(assign,"assign assign-open"));
    			}
    			var reducedScoreDate = config.parseWWDate(assign.get("due_date")).date.subtract("minutes",self.reducedScoringMinutes);
    			if(reducedScoreDate.isSame(day.model,"day")){
					day.$el.append(self.createAssignInfoBar(assign,"assign assign-reduced-credit"));
    			}
    		});
    	},
    	createAssignInfoBar: function(assign,_classes){
    		return this.template({classes: _classes, setname: assign.get("set_id"), 
    				assignedUsers: assign.assignedUsers.length, totalUsers: 4, visibleToStudents: assign.get("visible"),
    				showName: true});
    	},

    	// This needs to determine the visual bars on the calendar.  
    	// OLD:  probably delete this function 
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

	var AssignmentInfoView = Backbone.View.extend({

		render: function(){

		}
	});
/* 
  // this came from the day render function of the Calendar View

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




*/

// more stuff from the CalendarView.  Do we need this?

 /*           var dayWidth = parseInt($("#calendar-table").width()/7)-20;
            $(".assign-open").truncate({width: dayWidth});
            $(".assign-reduced-credit").truncate({width: dayWidth});

            if (this.view === "student"){
                $(".assign-open,.assign-reduced-credit,.assign-not-visible").attr("data-content","");
            } 
            $(".assign-open,.assign-reduced-credit,.assign-not-visible").popover({placement: "top", html: true});*/




	return AssignmentCalendarView;
});
