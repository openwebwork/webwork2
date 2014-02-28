// This is the View for the dialog for addings students manually    

define(['backbone', 'underscore','models/User','models/UserList','config','stickit'], 
	function(Backbone, _, User, UserList, config){	
	var AddStudentManView = Backbone.View.extend({
		id: "addStudManDialog",	    
		initialize: function(options){
		    var self=this;
		    _.bindAll(this, 'render','importStudents','addStudent','openDialog','closeDialog'); // every function that uses 'this' as the current object should be in here
		    this.courseUsers = options.users; 
		    this.$el.dialog({autoOpen: false, modal: true, title: "Add Students by Hand",
							width: (0.95*window.innerWidth), height: (0.60*window.innerHeight) });
		},
		rowTemplate: $("#user-row-template").html(),
		events: {
		    "click button#import-stud-button": "importStudents",
		    "click button#add-more-button": "addStudent",
		    "click button#cancel-import": "closeDialog"
		},
		openDialog: function () { 
			var self = this;
			this.$el.dialog("open");
			this.collection = new UserList([new User()]);  // add a single blank user to the collection of students to import.		    		    
			this.collection.on({add: this.render, remove: this.render}).courseUsers = this.courseUsers;
			this.render();
		},
		closeDialog: function () {this.$el.dialog("close");},
		render: function(){
			var self = this;
		    this.$el.html($("#manual-import-template").html());
		    var table = this.$("table#man_student_table tbody");
		    this.collection.each(function(user){ 
			    table.append(new UserRowView({model: user, rowTemplate: self.rowTemplate}).render().el);
		    });
		},
		importStudents: function(){  // validate each student data then if successful upload to the server.
		    var self = this;
		    var usersValid = this.collection.map(function(model){ return model.isValid(true);});
		    if (_.all(usersValid, _.identity)) { 
		    	this.closeDialog();
		    	this.collection.each(function(_user) {
		    		_user.id = void 0; // to ensure that it is a new user. 
		    		self.courseUsers.add(_user);
		    	});
			}
		},
		addStudent: function (){ 
			var user = new User()
			user.id="temp"+(this.collection.length+1); // to make sure a unique id is generated. 
			this.collection.add(user);
		}
    });

	var UserRowView = Backbone.View.extend({
        tagName: "tr",
        initialize: function (options) {
        	var self = this;
            _.bindAll(this,'render');
        	this.invBindings = _.extend(_.invert(_.omit(this.bindings,".permission")),
        		{"user_id": ".login-name", "email_address": ".email"});
		    this.rowTemplate = options.rowTemplate;
		    Backbone.Validation.bind(this, {
		    	invalid: function(view,attr,error){
		    		self.$(self.invBindings[attr]).popover({placement: "right", content: error})
                    	.popover("show").addClass("error");
		    	}
		    });
		
        },
        render: function () {
            this.$el.html(this.rowTemplate);
            this.stickit();
            return this; 
	    },       
    	bindings : { ".student-id": "student_id",
    				".last-name": "last_name",    		
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
    					selectOptions: { collection: function() { return config.permissions;}}
    				}
    			},
        events: {
		    'click .delete-button': 'removeRow'
		},
		removeRow: function () { 
			console.log("in removeRow");
			this.model.collection.remove(this.model); 

			this.$el.remove();	
		}

    });


    return AddStudentManView;

});
    