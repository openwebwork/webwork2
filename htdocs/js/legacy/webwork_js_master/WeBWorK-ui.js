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
    tagName: "div",
    className: "alert fade in",
    text: "",
    display: "none",
    initialize: function(){
	_.bindAll(this, 'render','close','setText'); // every function that uses 'this' as the current object should be in here
        if (!(this.options.text == undefined)) {this.text = this.options.text;}
        if (!(this.options.display == undefined)) {this.display = this.options.display;}
	this.render();
        return this;
    },
    events: {
	'button.close': 'close'
    },
    render: function(){
            this.$el.html("<div class='row-fluid'><div class='span11 closeable-text'></div><div class='span1 pull-right'>" +
                          " <button type='button' class='close'>&times;</button></div></div>");
            $(".closeable-text",this.el).html(this.text);
            this.$el.css("display",this.display);
            
	    return this; // for chainable calls, like .render().el
	},
    close: function () {
        var self = this;
        this.$el.fadeOut("slow", function () { self.$el.css("display","none"); })},
    setText: function (str) {
        $(".closeable-text",this.el).html(str);
        this.open();
    },
    appendText: function(str) {
	$(".closeable-text",this.el).append(str);
    },
    open: function (){
        var self = this;
        this.$el.fadeIn("slow", function () { self.$el.css("display","block"); })
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
