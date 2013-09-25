// This is the View for the dialog for addings students manually    

define(['Backbone', 'underscore','views/Closeable','models/User','models/UserList','config','stickit'], 
	function(Backbone, _, Closeable, User, UserList, config){	
	var AddStudentManView = Backbone.View.extend({
		id: "addStudManDialog",	    
		initialize: function(){
		    var self=this;
		    _.bindAll(this, 'render','importStudents','addStudent','openDialog','closeDialog'); // every function that uses 'this' as the current object should be in here
		    this.collection = new UserList([new User()]);  // add a single blank user to the collection of students to import.		    		    

		    this.rowTemplate = $("#user-row-template").html();
		    this.collection.bind('add', this.render);
		    this.courseUsers = this.options.users; 
		    this.render();
		    
		    this.$el.dialog({autoOpen: false, modal: true, title: "Add Students by Hand",
							width: (0.95*window.innerWidth), height: (0.60*window.innerHeight) });
		    
		    /*this.collection.on('error',function(model, error) {
				self.errorPane.addMessage(error.message);
		    }); */

		    
		    
	     	Backbone.Validation.bind(this);
		},
		events: {
		    "click button#import-stud-button": "importStudents",
		    "click button#add-more-button": "addStudent",
		    "click button#cancel-import": "closeDialog"
		},
		openDialog: function () { this.$el.dialog("open");},
		closeDialog: function () {this.$el.dialog("close");},
		template: _.template($("#add_student_man_dialog_content").html()),
		render: function(){
			var self = this;
		    this.$el.html($("#manStudentTableTmpl").html());
		    var table = this.$("table#man_student_table tbody");
		    this.tableRows = []; 
		    this.collection.each(function(user){ 
		    	var tableRow = new UserRowView({model: user, rowTemplate: self.rowTemplate});
			    table.append(tableRow.render().el);
			    self.tableRows.push(tableRow);
		    });
		    
			    
		    //this.errorPane = new Closeable({el: this.$("#error-pane-add-man"), classes : ["alert-error"]});
		    
		    
		    
		},
		importStudents: function(){  // validate each student data then if successful upload to the server.
		    var self = this;
		    var usersValid = _(this.tableRows).map(function(row){ return row.isValid();});
		    
		    console.log(usersValid);
		    
		    if (_.all(usersValid, _.identity)) { 
		    	this.closeDialog();
		    	this.collection.each(function(_user) {
		    		_user.save(
		    			{ error: function(model, xhr, options){ 
		    				console.log(model);
		    				console.log(xhr);
		    				console.log(options);}, 
		    			success: function(model, response, options){
	    					console.log(model);
		    				console.log(response);
		    				console.log(options);
		    				}});
		    		self.courseUsers.add(_user);});
		    }
		},
		addStudent: function (){ 
			this.collection.add(new User());
		}
    });

	var UserRowView = Backbone.View.extend({
        tagName: "tr",
        initialize: function () {
            _.bindAll(this,'render','isValid');
        	this.invBindings = _.extend(_.invert(_.omit(this.bindings,".permission")),{"user_id": ".login-name", "email_address": ".email"});
		    this.rowTemplate = this.options.rowTemplate;
		    this.permissions = config.permissions;
		
        },
        render: function () {
            this.$el.html(this.rowTemplate);
            this.stickit();
            return this; 
	    },       
    	bindings : { ".student-id": "student_id",
    				".last-name": {
    					observe: "last_name",
    				},
    				".first-name": "first_name",
    				".status": "status",
    				".comment": "comment",
    				".status": "status",
    				".recitation": "recitation",
    				".email": {observe: "email_address", setOptions: {silent:true}},
    				".login-name": {observe: "user_id", setOptions: {silent:true}},
    				".password": "password",
    				".permission": { 
    					observe: "permission",
    					selectOptions: { collection: "this.permissions",
    								labelPath: "label", valuePath: "value"}
    				}
    			},
        events: {
		    'click delete-button': 'removeRow'
		},
		isValid: function() { // checks if the user data is valid and shows error messages. 
			var self = this; 
	    	var errors = this.model.validate();
	    	console.log(this.model);
	    	console.log(errors);

        	if(errors){
                _(errors).chain().keys().each(function(attr){
                    self.$(self.invBindings[attr]).popover({placement: "top", content: errors[attr]})
                    	.popover("show").addClass("error");
        	    });
            }
            return errors === undefined; 

		},
		removeRow: function () { 
			console.log("in removeRow");
			this.model.collection.remove(this.model,{silent: true}); 
			this.$el.remove();	
		}

    });


    return AddStudentManView;

});
    