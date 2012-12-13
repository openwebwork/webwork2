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


return ui;

});



