/*  problemsetlist.js:
   This is the base javascript code for the ProblemSetList.pm (Homework Editor3).  This sets up the View and ....
  
*/


$(function(){
    
    // get usernames and keys from hidden variables and set up webwork object:
    var myUser = document.getElementById("hidden_user").value;
    var mySessionKey = document.getElementById("hidden_key").value;
    var myCourseID = document.getElementById("hidden_courseID").value;
    // check to make sure that our credentials are available.
    if (myUser && mySessionKey && myCourseID) {
        webwork.requestObject.user = myUser;
        webwork.requestObject.session_key = mySessionKey;
        webwork.requestObject.courseID = myCourseID;
    } else {
        alert("missing hidden credentials: user "
            + myUser + " session_key " + mySessionKey
            + " courseID" + myCourseID, "alert-error");
    }

    var HomeworkEditorView = webwork.ui.WebPage.extend({
	tagName: "div",
        initialize: function(){
	    webwork.ui.WebPage.prototype.initialize.apply(this);
	    _.bindAll(this, 'render');  // include all functions that need the this object
	    var self = this;
            
            
            this.render();
        },
        render: function(){
	    var self = this; 
	    //this.$el.html("");
	    
	    // Create an announcement pane for successful messages.
	    
	    this.announce = new webwork.ui.Closeable({id: "announce-bar"});
	    this.announce.$el.addClass("alert-success");
	    this.$el.append(this.announce.el)
	    $("button.close",this.announce.el).click(function () {self.announce.close();}); // for some reason the event inside this.announce is not working  this is a hack.
            //this.announce.delegateEvents();
	    
   	    // Create an announcement pane for successful messages.
	    
	    this.errorPane = new webwork.ui.Closeable({id: "error-bar"});
	    this.errorPane.$el.addClass("alert-error");
	    this.$el.append(this.errorPane.el)
	    $("button.close",this.errorPane.el).click(function () {self.errorPane.close();}); // for some reason the event inside this.announce is not working  this is a hack.
	    
	    
   	    this.helpPane = new webwork.ui.Closeable({display: "block",text: $("#homeworkEditorHelp").html(),id: "helpPane"});
	    this.$el.append(this.helpPane.el)
	    $("button.close",this.helpPane.el).click(function () {self.helpPane.close();}); // for some reason the event inside this.announce is not working  this is a hack.
            
            this.calendarView = new CalendarView({date: new XDate(2012,1,14)});
            this.$el.append(this.calendarView.el);
            
        }
    });
    
    var CalendarDayView = Backbone.View.extend({ // This displays a day in the Calendar
        tagName: "td",
        className: "calendar-day",
        initialize: function (){
            _.bindAll(this, 'render');  // include all functions that need the this object
	    var self = this;
            this.today = this.options.today; 
            this.render();
            return this;
        },
        render: function () {
            var str = (this.model.getDate()==1)? this.model.toString("MMM dd") : this.model.toString("dd");
            this.$el.html(str);
            if (this.today.getMonth()===this.model.getMonth()){this.$el.css("background","lightyellow");}
            if (this.today.getDate()===this.model.getDate()){this.$el.css("background","orange");}
            return this;
        }
    });
      
      
    var CalendarRowView = Backbone.View.extend({  // This displays a row of the Calendar
        tagName: "tr",
        className: "calendar-row",
        initialize: function (){
            _.bindAll(this, 'render');  // include all functions that need the this object
	    if (this.options) {this.week=this.options.week; this.today = this.options.today;}
            this.render();
            return this; 
        },
        render: function () {
            var self = this;
            _(this.week).each(function(date) {
                var calendarDay = new CalendarDayView({model: date, today: self.today});
                self.$el.append(calendarDay.el);
            });
            return this;
            }
        });
    
    var CalendarView = Backbone.View.extend({
        tagName: "table",
        className: "calendar",
        initialize: function (){
            _.bindAll(this, 'render');  // include all functions that need the this object
	    var self = this;
            if (this.options.date) {this.date = this.options.date;}
            if (! this.date) { this.date = new XDate();}
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
                var calendarWeek = new CalendarRowView({week: theWeek,today: this.date});
                this.$el.append(calendarWeek.el);                
            }
            return this;   
        }
    });
    
    var App = new HomeworkEditorView({el: $("div#mainDiv")});
});