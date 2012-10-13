// An object containing some of the User Interface objects for WeBWorK

webwork.ui ={};

webwork.ui.ChangePasswordRowView = Backbone.View.extend({
	tagName: "tr",
	className: "CPuserRow",
	initialize: function(){
	    _.bindAll(this, 'render','updatePassword'); // every function that uses 'this' as the current object should be in here
	    this.render();
            return this;
	},
	events: {
	    'change input': 'updatePassword'
	},
	render: function(){
            this.$el.html("<td> " + this.model.attributes.first_name + "</td><td>" + this.model.attributes.last_name + "</td><td>"
                          + this.model.attributes.user_id +" </td><td><input type='text' size='10' class='newPass'></input></td>");

	    return this; // for chainable calls, like .render().el
	},
       updatePassword: function(evt){  
	    var changedAttr = evt.target.className.split("for-")[1];
	    this.model.set("new_password",evt.target.value, {silent: true}); // so a server hit is not made at this moment.  
	    console.log("new password: " + evt.target.value);
	}
    });


webwork.ui.EmailStudentsView = Backbone.View.extend({
	tagName: "div",
	className: "emailDialog",
	initialize: function() { _.bindAll(this,"render"); this.render(); return this;},
   render: function ()
   {
        var self = this; 
        this.$el.html(_.template($("#emailStudentTemplate").html(),this.model));
	this.model.each(function (user){
	$("#emailStudentList",self.$el).append(user.attributes.first_name + " " + user.attributes.last_name + ",");	
		});
	
	
        this.$el.dialog({autoOpen: false, modal: true, title: "Password Changes",
			width: (0.75*window.innerWidth), height: (0.75*window.innerHeight),
                        buttons: {"Send Email": function () {self.sendEmail(); self.$el.dialog("close")},
                                  "Cancel": function () {self.$el.dialog("close");}}
                        });
   },
   sendEmail: function ()
   {
	
   }
});

webwork.ui.ChangePasswordView = Backbone.View.extend({
    tagName: "div",
    className: "passwordDialog",
    initialize: function() { _.bindAll(this,"render"); this.render(); return this;},
   render: function ()
   {
        var self = this; 
        this.$el.html(_.template($("#passwordDialogText").html(),this.model));
        this.model.each(function (user) {
            var tableRow = new webwork.ui.ChangePasswordRowView({model: user});
            $("table tbody",self.$el).append(tableRow.el);
        });
        
        this.$el.dialog({autoOpen: false, modal: true, title: "Password Changes",
			width: (0.5*window.innerWidth), height: (0.5*window.innerHeight),
                        buttons: {"Save New Passwords": function () {self.savePasswords(); self.$el.dialog("close")},
                                  "Cancel": function () {self.$el.dialog("close");}}
                        });
   },
   savePasswords: function () {
        this.model.each(function(user) {user.change();});
   }
   
   
});

/* This is a class of closeable Divs that take functionality from Boostrap-alert.  See http://twitter.github.com/bootstrap/javascript.html#alerts */

webwork.ui.Closeable = Backbone.View.extend({
    className: "closeablePane",
    text: "",
    display: "none",
    initialize: function(){
	var self = this; 
	_.bindAll(this, 'render','setHTML','close','clear','appendHTML','open'); // every function that uses 'this' as the current object should be in here
        if (this.options.text !== undefined) {this.text = this.options.text;}
        if (this.options.display !== undefined) {this.display = this.options.display;}
	this.$el.addClass("alert");
	_(this.options.classes).each(function (cl) {self.$el.addClass(cl);});
	
	this.render();
	
	this.isOpen = false; 
        return this;
    },
    events: {
	'click button.close': 'close'
    },
    render: function(){
            this.$el.html("<div class='row-fluid'><div class='span11 closeable-text'></div><div class='span1 pull-right'>" +
                          " <button type='button' class='close'>&times;</button></div></div>");
            this.$(".closeable-text").html(this.text);
            this.$el.css("display",this.display);
            
	    return this; // for chainable calls, like .render().el
	},
    close: function () {
	this.isOpen = false; 
        var self = this;
        this.$el.fadeOut("slow", function () { self.$el.css("display","none"); });
    },
    setHTML: function (str) {
        this.$(".closeable-text").html(str);
        if (!this.isOpen){this.open();}
    },
    clear: function () {
	this.$(".closeable-text").html("");
    },
    appendHTML: function(str) {
	this.$(".closeable-text").append(str);
	if (!this.isOpen){this.open();}
	
    },
    open: function (){
	this.isOpen = true;
        var self = this;
        this.$el.fadeIn("slow", function () { self.$el.css("display","block"); })
    }
});


webwork.ui.CalendarDayView = Backbone.View.extend({ // This displays a day in the Calendar
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
      
      
webwork.ui.CalendarRowView = Backbone.View.extend({  // This displays a row of the Calendar
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
                var calendarDay = new webwork.ui.CalendarDayView({model: date, calendar: self.calendar});
                self.$el.append(calendarDay.el);
            });
            return this;
            }
        });
    
webwork.ui.CalendarView = Backbone.View.extend({
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
                var calendarWeek = new webwork.ui.CalendarRowView({week: theWeek, calendar: this});
                this.$el.append(calendarWeek.el);                
            }
            return this;   
        }
    });
    


/* This is the class webwork.WebPage that sets the framework for all webwork webpages */

webwork.ui.WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    initialize: function () {
//         this.announceView = new webwork.ui.CloseableDiv({border: "2px solid darkgreen", background: "lightgreen"});
//         this.helpView = new webwork.ui.CloseableDiv();
        },
    });




