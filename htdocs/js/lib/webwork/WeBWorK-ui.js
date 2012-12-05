// An object containing some of the User Interface objects for WeBWorK
define(['Backbone', 'underscore', 'XDate'], function(Backbone, _, XDate){

var ui ={};

/* In conjuction with the ui.ChangePasswordView, these Views provide basic ui interface for a password change. */

ui.ChangePasswordRowView = Backbone.View.extend({
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


ui.ChangePasswordView = Backbone.View.extend({
    tagName: "div",
    className: "passwordDialog",
    initialize: function() { _.bindAll(this,"render"); this.render(); return this;},
   render: function ()
   {
        var self = this; 
        this.$el.html(_.template($("#passwordDialogText").html(),this.model));
        this.model.each(function (user) {
            var tableRow = new ui.ChangePasswordRowView({model: user});
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

/* 
This is a table row that contains a key-value pair generally for a set of properties.  The property description is passed in 
the description field and the value in the value field.  For example:

new ui.EditableRow({description: "How long is the piece of string": value: "6 inches"});
*/

ui.EditableRow = Backbone.View.extend({
    tagName: "tr",
    initialize: function () {
        _.bindAll(this, 'render');
        _.extend(this,this.options);
        this.render();
    },
    render: function () {
         this.$el.append("<td class='srv-name'> " + this.model["descriptions"][this.property] + "</td> ");
         var ec = new ui.EditableCell({model: this.model, property: this.property});

         this.$el.append(ec.render().el);
    }

});


/* 
  This view displays all key/value pairs in an object.  There is no nesting of properties and the descriptions are 
  listed in a descriptions field of the object.  For example, a small propertylist would be

  var PropertyList = {key1: "value1", key2: "value2", key3: "value3", descriptions:
    key1: "This describes key1", key2: "This describes key2", key3: "This describes key3"}}; 
*/
    
    ui.PropertyListView = Backbone.View.extend({
        className: "settings-view",
        initialize: function () {
            _.bindAll(this, 'render');  // include all functions that need the this object
            _.extend(this, this.options);
            this.render();
        },
        render: function () {
            var self = this;
            var props = _(this.model["descriptions"]).map(function (_value,_key) {return _key;});  // array of all of the keys
            this.$el.html("<table class='table bordered-table'><thead><tr><th>Property</th><th>Value</th></tr></thead><tbody></tbody></table>");
            var tab = this.$("table");
            if (this.showProperties){
                props = _(props).intersection(this.showProperties);

            }
             _(props).each(function(_prop){
                var row = new ui.EditableRow({model: self.model, property: _prop} ); 
                //description: self.model.get("descriptions")[_prop], 
                  //      key: _prop , value: self.mdoel.get(_prop)});
                tab.append(row.el);
            });
           
        }
        });



/* This is the ui for sending email.  As of 10/2012, it's a shell that doesn't do anything.  */

ui.EmailStudentsView = Backbone.View.extend({
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



/* This is a class of closeable Divs that take functionality from Boostrap-alert.  See http://twitter.github.com/bootstrap/javascript.html#alerts 


*/

/*ui.Closeable = Backbone.View.extend({
    className: "closeablePane",
    text: "",
    display: "none",
    initialize: function(){
    	var self = this; 
    	_.bindAll(this, 'render','setHTML','close','clear','appendHTML','open'); // every function that uses 'this' as the current object should be in here
        _.extend(this,this.options);    
        this.$el.addClass("alert");
    	_(this.options.classes).each(function (cl) {self.$el.addClass(cl);});
    	

        if (localStorage.getItem("closeHelpClicks")===null)
        {
            localStorage.setItem("closeHelpClicks","0")
        }

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

            if ((this.closeableType === "Help") && (parseInt(localStorage.getItem("closeHelpClicks")) > 3)){
                this.$el.css("display","none");
            } else {
                this.$el.css("display",this.display);
            }
            
	    return this; // for chainable calls, like .render().el
	},
    close: function () {
        this.isOpen = false; 
        var self = this;
        if (this.closeableType === "Help") {
            var clicks = parseInt(localStorage.getItem("closeHelpClicks")) +1;
            localStorage.setItem("closeHelpClicks",""+clicks);
            if (clicks >3) {
                alert("You have closed the Help Menu more that three times. " +
                    " For convenience, we will not autoopen this.  You can reopen Help with the Help Button" +
                    " at the top of the page.");
            }

        }


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


ui.CalendarDayView = Backbone.View.extend({ // This displays a day in the Calendar
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
      
      
ui.CalendarRowView = Backbone.View.extend({  // This displays a row of the Calendar
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
                var calendarDay = new ui.CalendarDayView({model: date, calendar: self.calendar});
                self.$el.append(calendarDay.el);
            });
            return this;
            }
        });
    
ui.CalendarView = Backbone.View.extend({
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
                var calendarWeek = new ui.CalendarRowView({week: theWeek, calendar: this});
                this.$el.append(calendarWeek.el);                
            }
            return this;   
        }
    });
    */


/* This is the class webwork.WebPage that sets the framework for all webwork webpages */

ui.WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    initialize: function () {
//         this.announceView = new ui.CloseableDiv({border: "2px solid darkgreen", background: "lightgreen"});
//         this.helpView = new ui.CloseableDiv();
        },
    render: function () {
                // Create an announcement pane for successful messages.
        
        this.announce = new ui.Closeable({el:$("#announce-pane"),classes: ["alert-success"]});
        
        
        // Create an announcement pane for successful messages.
        
        this.errorPane = new ui.Closeable({el:$("#error-pane"),classes: ["alert-error"]});

    }
    });

return ui;

});



