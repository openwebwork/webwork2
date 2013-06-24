/*  ClasslistManager.js:
   This is the base javascript code for the UserList3.pm (Classlist Manager).  This sets up the View and the classlist object.
  
*/

require(['Backbone', 
	'underscore',
	'../globals',
	'../../lib/models/User', 
	'../../lib/models/UserList', 
	'editablegrid', 
	'WebPage', 
	'../../lib/views/EmailStudentsView',
	'../../lib/views/ChangePasswordView',
	'./AddStudentFileView',
	'./AddStudentManView',
	'../../lib/util', 
	'config', /*no exports*/, 
	'jquery-ui',
	'backbone-validation',
	'bootstrap',
	'jquery-ui'], 
function(Backbone, _, globals, User, UserList, EditableGrid, WebPage, EmailStudentsView, 
		ChangePasswordView, AddStudentFileView, AddStudentManView, util, config){


    var UserListView = WebPage.extend({
	tagName: "div",
        initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','deleteUsers','changePassword','gridChanged','updatePaginator');  // include all functions that need the this object
	    var self = this;
	    this.users = (globals.users) ? new UserList(globals.users): new UserList();
	    
	    
	    this.grid = new EditableGrid("user-grid",{ enableSort: true,pageSize: 10});
		var _data = this.users.map(function(user) { return {id: user.cid, values: user.attributes};});
		this.grid.load({metadata: config.userTableHeaders, data: _data});
		this.customizeGrid();
	    this.grid.modelChanged = this.gridChanged;
	    this.addStudentManView = new AddStudentManView({users: this.users});
	    this.addStudentFileView = new AddStudentFileView({users: this.users});
	    this.render();
	    

            
	    this.users.on('add',function(user){
	    	self.grid.append(user.cid, user.toJSON());
	    	self.updatePaginator();
		    //if (userInfo.login_status==1){
			//	self.loggedInUsers.push(user.cid);
		    //}
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

	    //this.postLoadingTasks();
	    
	    
    },
    render: function(){
    	this.$el.empty();
    	this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
	    
    	this.$el.append($("#classlist-manager-template").html());
		this.grid.renderGrid("users-table-container","table table-bordered table-condensed","users-table");
		this.grid.setPageIndex(0);
		this.updatePaginator(0);
	    
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
	updatePaginator: function (page) {
		var numPages = this.grid.getPageCount()
			, pageStart = page < 10 ? 0 : page-10
			, pageEnd = numPages-page < 10 ? numPages : ((page<10) ? 20: page+10);
		$("#users-table-paginator").empty()
			.html(_.template($("#paginator-template").html(),{page_start: pageStart, page_stop: pageEnd, num_pages: numPages}));
		this.delegateEvents();
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
	    $("#usersShownInfo").html(this.grid.getRowCount() + " of " + this.users.length + " users shown.");
		
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
			var grid = this.grid;
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
    getSelectedUsers: function() {
    	var users = $("td:nth-child(1) input[type='checkbox']:checked").closest("tr")
    			.children("td:nth-child(3)").map(function(i,v) {return $(v).html();}).get();
    	return this.users.filter(function(user) { return (_(users).indexOf(user.get("user_id")) > -1);});
    },
    changePage: function (evt) {
    	
		var newPageIndex = $(evt.target).data("page");
		this.updatePaginator(newPageIndex);
		this.$("button.page-button[data-page='" + newPageIndex + "']").prop("disabled",true);
		this.grid.setPageIndex(newPageIndex);

	},
	showFirstPage: function () {
		this.grid.setPageIndex(0);
		this.updatePaginator(0);
		this.$(".goto-first,.go-back-one,.page-button[data-page='0']").prop("disabled",true);
	},
	showPreviousPage: function (){
		var currentPage = this.grid.getCurrentPageIndex() -1 ;
		this.updatePaginator(currentPage);
		this.$("button.page-button[data-page='" + currentPage + "']").prop("disabled",true);
		if (currentPage == 0){
			this.$(".goto-first,.go-back-one").prop("disabled",true);
		}
		this.grid.setPageIndex(currentPage);
	},
	showNextPage: function (){
		var currentPage = this.grid.getCurrentPageIndex() +1 ;
		this.updatePaginator(currentPage);
		this.$("button.page-button[data-page='" + currentPage + "']").prop("disabled",true);
		if (currentPage == this.grid.getPageCount() -1){
			this.$(".goto-end,.go-forward-one").prop("disabled",true);
		}

		this.grid.setPageIndex(currentPage);
	},
	showLastPage: function () {
		var lastIndex = this.grid.getPageCount()-1;
		this.grid.setPageIndex(lastIndex);
		this.updatePaginator(lastIndex);
		this.$(".goto-end,.go-forward-one,.page-button[data-page='" + lastIndex + "']").prop("disabled",true);	
	},
	filterUsers: function (evt) {
	    this.grid.filter($("#filter").val());
	    $("#usersShownInfo").html(this.grid.getRowCount() + " of " + this.users.length + " users shown.");
	},
	clearFilterText: function () {
		$("input#filter").val("");
		this.grid.filter("");
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

		this.grid.setHeaderRenderer("Select", new SelectAllRenderer());
		this.grid.setCellRenderer("Action", new CellRenderer({
			render: function(cell, value) { 
				$(cell).html("<i class='icon-cog'></i>"); }
		}));
	},

	deleteUsers: function(rows){
		var rows = $("td:nth-child(1) input[type='checkbox']:checked").closest("tr")
						.map(function(i,v) {return $(v).index();}).get();

	    rowsBackwards = _(rows).sortBy(function (num) { return -1*num;});  // the rows need to be sorted in decreasing order so the rows in the table are
									// removed correctly. 

		var users = this.getSelectedUsers();							
	    var self = this;
	    var str = "Do you wish to delete the following students: " + 
	    _(users).map(function (user) {return user.get("first_name") + " "+ user.get("last_name")}).join(", ");
	    var del = confirm(str);
		    
	    if (del){
			_(rowsBackwards).each(function (row){self.grid.remove(row);});
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


