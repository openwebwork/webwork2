/*  ClasslistManager.js:
   This is the base javascript code for the UserList3.pm (Classlist Manager).  This sets up the View and the classlist object.
  
*/

require(['Backbone', 
	'underscore',
	'apps/globals',
	'models/User', 
	'models/UserList', 
	'editablegrid', 
	'WebPage', 
	'views/EmailStudentsView',
	'views/ChangePasswordView',
	'AddStudentFileView',
	'AddStudentManView',
	'../lib/util', 
	'views/EditGrid',
	'config', /*no exports*/, 
	'jquery-ui',
	'backbone-validation',
	'bootstrap',
	'jquery-ui'], 
function(Backbone, _, globals, User, UserList, EditableGrid, WebPage, EmailStudentsView, 
		ChangePasswordView, AddStudentFileView, AddStudentManView, util, EditGrid,config){


    var UserListView = WebPage.extend({
	tagName: "div",
        initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','deleteUsers','changePassword','gridChanged');  // include all functions that need the this object
	    var self = this;
	    this.users = (globals.users) ? new UserList(globals.users): new UserList();
	    

        this.editgrid = new EditGrid({grid_name: "users-table-container", table_name: "users-table",
        paginator_name: "#users-table-paginator", template_name: "#classlist-table-template",
        enableSort: true, pageSize: 10});
        
        this.editgrid.grid.load({metadata: config.userTableHeaders});
        this.customizeGrid();
        this.editgrid.grid.modelChanged = this.gridChanged;
	    this.addStudentManView = new AddStudentManView({users: this.users});
	    this.addStudentFileView = new AddStudentFileView({users: this.users});
	    this.render();
	    

            
	    this.users.on('add',function(user){
	    	self.editgrid.grid.append(user.cid, user.toJSON());
	    	self.updatePaginator();
	    });

	    // This handles all of the messages posted at the top of the page when updates are made to the user list.  
	    this.users.on('success', function (type, user) {
			
			
		    // pstaabp:  this seems clunky.  Perhaps we can clean up this code. 	
			switch(type) {
			    case "user_added":
					    this.announce.addMessage({text: "Success in adding the following user: " + user.get("user_id")});
					break;
			    case "user_deleted":
					    this.announce.addMessage({text: "Success in deleting the following user: " + user.get("user_id")});
					break;
			    case "property_changed":
			    	for(prop in user.changedAttributes()) { 
			    		console.log(prop + " " + user.changedAttributes()[prop]);
	  						this.announce.addMessage({text: "The " + prop + " of user " + user.get("user_id") + " has changed "
							    + "from " + user.oldAttributes[prop] + " to " + user.get(prop)});

			    	}
				break;
			}
		},this);
	   
	    	    
	    $("div#addStudFromFile").dialog({autoOpen: false, modal: true, title: "Add Student from a File",
					    width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
	     

	    // Make sure the take Action menu item is reset
	    $("button#help-link").click(function () {self.helpPane.open();});	    
	    
    },
    render: function(){
    	this.$el.empty();
    	this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
	    
    	this.$el.append($("#classlist-manager-template").html());

    	this.editgrid.setElement($("#users-table-container"));
        this.editgrid.render();
        this.updateGrid();
	    this.$(".num-users").html(this.editgrid.grid.getRowCount() + " of " + this.users.length + " users shown.");
	    this.$el.append(this.passwordPane = new ChangePasswordView());
	    this.$el.append(this.emailPane = new EmailStudentsView()); 
	    return this;
    },
    events: {
    	"click .delete-selected": "deleteUsers",
    	"click .password-selected": "changePassword",
    	"click .email-selected": "emailStudents",
	    "click .add-students-file-option": "addStudentsByFile",
	    "click .add-students-man-option": "addStudentsManually",
	    "click .export-students-option": "exportStudents",
		'keyup input#filter' : 'filterUsers',
	    'click button#clear-filter-text': 'clearFilterText',
	    'change input.select-all-header': 'selectAll',
	    "click .page-button": "changePage",
	    'click button.goto-first': "showFirstPage",
	    'click button.go-back-one' : "showPreviousPage",
	    'click button.go-forward-one': "showNextPage",
	    'click button.goto-end': "showLastPage",
	},
	addStudentsByFile: function () {
		this.addStudentFileView.openDialog();
	},
	addStudentsManually: function () {
		this.addStudentManView.openDialog();
	},
	exportStudents: function () {
	    var bb = new BlobBuilder;
	    
	    // Write the headers out
	    bb.append((_(config.userProps).map(function (prop) { return "\"" + prop.longName + "\"";})).join(",") + "\n");
	    
        // Write out the user Props
        this.users.each(function(user){bb.append(user.toCSVString())});
	    
        // need a more appropriate filename

        saveAs(bb.getBlob("text/csv;charset=utf-8"), "hello world.csv");            
	},	

	
	    // This function contains tasks after the users have been received from the database.
	       // Decorate the Table: 
	      // set the action column to have a cog initially.   Note: this is a hack to get an icon set in the Editable Table
	      // also set the color to green for those users who are logged in.  
	   
	    
	postLoadingTasks: function () {
	    var self = this;
		
	    _(this.loggedInUsers).each(function(user){
			$("tr#UserListTable_" + user + " td:nth-child(3)").css("color","green").css("font-weight","bold");
	    });
		
	    this.loggedInUsers = [];
	    // Display the number of users shown
	    $("#usersShownInfo").html(this.editgrid.grid.getRowCount() + " of " + this.users.length + " users shown.");
		
	    // bind the collection to the Validation.  See Backbone.Validation at https://github.com/thedersen/backbone.validation
	    
	    /*
	    Backbone.Validation.bind(this,{
		valid: function(view, attr, selector) {
		    //console.log("running valid");
		},
		invalid: function(view, attr, error,selector) {
		    console.log("running invalid");
		    self.error = {errorAttr: attr, errorText: error};
	        }
	    }); 
	  
	  */	

	},
	updateGrid: function (){
        var _data = this.users.map(function(user) { return {id: user.cid, values: user.attributes};});
        this.editgrid.grid.load({data: _data});
        this.editgrid.grid.refreshGrid();
        this.editgrid.updatePaginator();
    },
    gridChanged: function(rowIndex, columnIndex, oldValue, newValue) {

    	var self = this;
		
		if (columnIndex == 0 ) { return;}
		if (columnIndex == 1 )  // the takeAction column has been selected.
		{
		    
		   switch (newValue){
		    case "action1":  // Change Password
			self.changePassword([rowIndex]);
		    break;
		    case "action2":  // deleteUser
		    self.deleteUsers([rowIndex]);
		    break;
		    case "action3":  // Act as User
				var username = self.grid.getValueAt(rowIndex,2); //
				
				// send a relative path, but is this the best way?
				var url = "../../?user=" + config.requestObject.user + "&effectiveUser=" + username + "&key=" +
					    config.requestObject.session_key; 
				location.href = url;
		    break;
		    case "action4":  // Student Progress
				var username = self.grid.getValueAt(rowIndex,2); //
				
				// send a relative path, but is this the best way?
				var url = "../progress/student/" + username + "/?user=" + config.requestObject.user + "&effectiveUser=" + username + "&key=" +
					    config.requestObject.session_key; 
				location.href = url;
		    break;
		    case "action5":  // Email Student
			
			self.emailStudents([rowIndex]);
		    break;
		
		   }
		   
  		    // make sure that the cog icon is visible again.  
		    $("#users_table tr[id*='UserListTable'] td:nth-child(2)").html("<i class='icon-cog'></i>");

		}
		
		// check to make sure that the updated information needs to be sent to the server
		
		else if (oldValue !== newValue  ){
			var grid = this.editgrid.grid;
		    var cid = grid.getRowId(rowIndex);
		    var property = grid.getColumnName(columnIndex);
		    var editedModel = this.users.get(cid);
		    console.log("just before editedModel.set");
		    
		    // The following checks if the data validates.  
		    

		    if(editedModel.preValidate(property, newValue)){
				this.errorPane.appendHTML("There is an error in setting the " + property + " for user " 
							+ editedModel.attributes.user_id + " in the red box below. <br/>  ");
				$("tr#UserListTable_" + cid + " td:nth-child("+(columnIndex+1) + ")").css("background-color","rgba(255,0,0,0.5)");
				
		    } else {
				$("tr#UserListTable_" + cid + " td:nth-child("+(columnIndex+1) + ")").css("background","none");
				this.updatedUser = {user_id: editedModel.attributes.user_id, property: property, oldValue: oldValue, newValue: newValue};
				editedModel.set(property,newValue);
				editedModel.update();
			}
        }
		
    },
	filterUsers: function (evt) {
	    this.editgrid.grid.filter($("#filter").val());
	    this.$(".num-users").html(this.editgrid.grid.getRowCount() + " of " + this.users.length + " users shown.");
	},
	clearFilterText: function () {
		$("input#filter").val("");
		this.editgrid.grid.filter("");
	},
	selectAll: function () {
		this.$("td:nth-child(1) input[type='checkbox']").prop("checked",this.$(".select-all-header").prop("checked"));
	},
	customizeGrid: function (){
		function SelectAllRenderer() {}; 
		SelectAllRenderer.prototype = new CellRenderer();
		SelectAllRenderer.prototype.render = function(cell, value) {
			if (value) {
				$(cell).html("<input type='checkbox' class='select-all-header'>");
			}
		}

		this.editgrid.grid.setHeaderRenderer("Select", new SelectAllRenderer());
		this.editgrid.grid.setCellRenderer("Action", new CellRenderer({
			render: function(cell, value) { 
				$(cell).html("<i class='icon-cog'></i>"); }
		}));
	},
	getSelectedRows: function () {
		return $("td:nth-child(1) input[type='checkbox']:checked").closest("tr")
					.map(function(i,v) {return $(v).index();}).get();
	}, 
	getUsersByRows: function(rows){
		var self = this; 
		return _(rows).map(function(_row) {
			return self.users.get($("#users-table table tr:nth-child(" +(_row+1) + ")").attr("id").split("users-table-container_")[1]);
		});
	},
	deleteUsers: function(_rows){
		var self = this
			, rows = _.isArray(_rows) ? _rows: this.getSelectedRows()
		    , rowsBackwards = _(rows).sortBy(function (num) { return -1*num;})  // the rows need to be sorted in decreasing order so the rows in the table are
									// removed correctly. 
			, users = this.getUsersByRows(rows)						
	    	, str = "Do you wish to delete the following students: " + 
	    			_(users).map(function (user) {return user.get("first_name") + " "+ user.get("last_name")}).join(", ")
		    , del = confirm(str);
		    
	    if (del){
			_(rowsBackwards).each(function (row){self.editgrid.grid.remove(row);});
			_(users).each(function(user){self.users.remove(user);});

			this.render();
	    }
	},
	changePassword: function(rows){
		this.passwordPane.users=this.getSelectedUsers();
	    this.passwordPane.render();
	    this.passwordPane.$el.dialog("open"); 
	    },
	emailStudents: function(rows){
	    this.emailPane.users = this.getSelectedUsers();
	    this.emailPane.render();
	    this.emailPane.$el.dialog("open");
    },
	messageType: "",   // the type of message shown at the top of the page.     
	



    });

    
//    var userListView = new UserListView();

    var App = new UserListView({el: $("div#main")});
    



	
});


