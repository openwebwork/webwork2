    // This is the View for the dialog for addings students manually    

define(['Backbone', 
	'underscore',
	'Closeable',
	'../../lib/models/User',
	'config',
	'../../lib/views/UserRowView'], function(Backbone, _,Closeable,User,config,UserRowView){	
	var AddStudentManView = Backbone.View.extend({
		tagName: "div",
		id: "addStudManDialog",
	    
		initialize: function(){
		    var self=this;
		    _.bindAll(this, 'render','importStudents','addStudent','appendRow','openDialog','closeDialog'); // every function that uses 'this' as the current object should be in here
		    this.collection = new TempUserList();
		    
		    
		    this.collection.bind('add', this.appendRow);
		    this.parent = this.options.parent;
		    this.render();
		    
		    this.collection.add(new User);  // add a single blank line. 
		    
		    
		    this.$el.dialog({autoOpen: false, modal: true, title: "Add Students by Hand",
							width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
		    
		    this.collection.on('error',function(model, error) {
				self.errorPane.appendHTML(error.message + "<br/>");
		    });
		    
		     Backbone.Validation.bind(this);
		},
		events: {
		    "click button#import_stud_button": "importStudents",
		    "click button#add_more_button": "addStudent"
		},
		openDialog: function () { this.$el.dialog("open");},
		closeDialog: function () {this.$el.dialog("close");},
		template: _.template($("#add_student_man_dialog_content").html()),
		render: function(){
		    var self = this;
		    var tableHTML = "<table id='man_student_table'><tbody><tr><td>Delete</td>"
		    tableHTML += (_(config.userProps).map(function (prop) {return "<td>" + prop.longName + "</td>";})).join("") + "</tr></tbody></table>";
		    
		    this.$el.append(this.template({content: tableHTML}));
		    _(this.collection).each(function(user){ self.appendRow(user);}, this);
		    
			    
		    this.errorPane = new Closeable({el: this.$("#error-pane-add-man"), classes : ["alert-error"]});
		    
		    
		    
		},
		importStudents: function(){  // validate each student data then if successful upload to the server.
		    var self = this,
			usersValid = new Array();
			
		    this.errorPane.setHTML("");
		    
		    this.collection.each(function(user){
				_(user.attributes).each(function(value,key) {
			    
					var errorMessage = user.preValidate(key, value);
					if ((errorMessage!=="") && (errorMessage !== false)) {
						self.collection.trigger("error",user, {type: key, message: errorMessage}); 
					}
				});
			
				usersValid.push(user.isValid(true)===true);
		    });
		    
		    console.log(usersValid);
		    
		    if (_.all(usersValid, _.identity)) { 
		    	this.closeDialog();
		    	this.collection.each(function(_user) {self.parent.collection.add(_user);});
		    }
		},
		appendRow: function(user){
		    var tableRow = new UserRowView({model: user});
		    $("table#man_student_table tbody",this.el).append(tableRow.el);
		},
		addStudent: function (){ this.collection.add(new User());}
	    });
	    
	    // This is a Backbone collection of webwork.User(s).  This is different than the webwork.userList class  because we don't need
    // the added expense of additions to the server.
    
    var TempUserList = Backbone.Collection.extend({model:User});

    return AddStudentManView;

});
    