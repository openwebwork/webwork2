/*  userlist.js:
   This is the base javascript code for the UserList3.pm (Classlist Editor3).  This sets up the View and the classlist object.
  
*/

require.config({
    paths: {
        "Backbone":             "/webwork2_files/js/vendor/backbone/backbone",
        "backbone-validation":  "/webwork2_files/js/vendor/backbone/modules/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/vendor/jquery/jquery-ui",
        "underscore":           "/webwork2_files/js/vendor/underscore/underscore",
        "jquery":               "/webwork2_files/js/vendor/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/vendor/bootstrap/js/bootstrap",
        "util":                 "/webwork2_files/js/lib/util",
        "XDate":                "/webwork2_files/js/vendor/other/xdate",
        "WebPage":              "/webwork2_files/js/lib/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":            "/webwork2_files/js/lib/views/Closeable"
    },
    urlArgs: "bust=" +  (new Date()).getTime(),
    waitSeconds: 15,
     shim: {
        'jquery-ui': ['jquery'],
        'jquery-ui-custom': ['jquery'],
        'underscore': { exports: '_' },
        'Backbone': { deps: ['underscore', 'jquery'], exports: 'Backbone'},
        'bootstrap':['jquery'],
        'backbone-validation': ['Backbone'],
        'XDate':{ exports: 'XDate'},
        'config': ['XDate']
    }
});

require(['Backbone', 
	'underscore',
	'../../lib/models/User', 
	'../../lib/models/UserList', 
	'../../vendor/editablegrid-2.0.1/editablegrid', 
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
function(Backbone, _, User, UserList, EditableGrid, WebPage, EmailStudentsView, 
		ChangePasswordView, AddStudentFileView, AddStudentManView, util, config){


    var UserListView = WebPage.extend({
	tagName: "div",
        initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','addOne','addAll','deleteUsers','changePassword','gridChanged');  // include all functions that need the this object
	    var self = this;
	    this.collection = new UserList();  // This is a Backbone.Collection of users
	    
	    
	    
	    this.grid = new EditableGrid("UserListTable", { enableSort: true});
        this.grid.load({ metadata: config.userTableHeaders, data: [{id:0, values:{}}]});
	    
	    this.render();
	    
	    this.grid.renderGrid('users_table', 'usersTableClass', 'userTable');
	    this.collection.fetch();
	    this.grid.refreshGrid();
	    
	    
	    
	    this.grid.modelChanged = this.gridChanged; 
	    
	    // Resets the grid by deleting all rows and readding.  
	                                                     
        this.collection.on('reset', function(){
            while(self.grid.getRowCount() > 1){
                self.grid.remove(1);
            }
            self.addAll();
        }, this);

            
	    this.collection.on('add',this.addOne,this);

	    // This handles all of the messages posted at the top of the page when updates are made to the user list.  
	    this.collection.on('success', function (type, user) {
			
			
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
			// make sure that the cog icon is visible again.  
		        $("#users_table tr[id*='UserListTable'] td:nth-child(2)").html("<i class='icon-cog'></i>");

		},this);
	   
	   this.collection.on('fetchSuccess', function() {this.postLoadingTasks()},this);
	    	    
	    $("div#addStudFromFile").dialog({autoOpen: false, modal: true, title: "Add Student from a File",
					    width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
	     

	    // Make sure the take Action menu item is reset
	    $("select#mainActionMenu").val("takeAction");
	    $("button#help-link").click(function () {self.helpPane.open();});
	    
	    
    },
    events: {
	    'change select.actionMenu' : 'takeBulkAction',
	    'change select#import-export' : 'importExportOptions',
	    'change input#selectAllCB' : 'toggleAllCheckBoxes',
	    'keyup input#filter' : 'filterUsers',
	    'click button#clear-filter-text': 'clearFilterText'
	},
	filterUsers: function (evt) {
	    this.grid.filter($("#filter").val());
	    $("#usersShownInfo").html(this.grid.getRowCount() + " of " + this.collection.length + " users shown.");
	},
	clearFilterText: function () {
		$("input#filter").val("");
		this.grid.filter("");
	},
	importExportOptions: function (evt) {
	    switch(evt.target.value){
		case "Add Students from a File":
		    var addStudFileDialog = new AddStudentFileView({parent: this});
		    addStudFileDialog.openDialog();
		    break;
		case "Add Students Manually":
		    var addStudManDialog = new AddStudentManView({parent: this});
		    addStudManDialog.openDialog();
		    break;
		case "Export Students to a File":
		    var bb = new BlobBuilder;
		    
		    // Write the headers out
		    bb.append((_(config.userProps).map(function (prop) { return "\"" + prop.longName + "\"";})).join(",") + "\n");
		    
            // Write out the user Props
            this.collection.each(function(user){bb.append(user.toCSVString())});
		    
            // need a more appropriate filename

            saveAs(bb.getBlob("text/csv;charset=utf-8"), "hello world.csv");            


		break;
	    }
	    
	    $(evt.target).val("Import or Export Students");
	    },
	
	takeBulkAction: function (evt) { 

		var selectedRows = [];

		for(var i = 0; i < this.grid.getRowCount(); i++){
			if ($("#"+ $(this.grid.getRow(i)).attr("id") + " input:checkbox").attr("checked") === "checked"){
				selectedRows.push(i);
			}

		}

		switch (evt.target.value){
	        case "menuEmail":
			    this.emailStudents(selectedRows);
			    break;
			case "menuChangePassword":
			    this.changePassword(selectedRows);
			    break;
			case "menuDelete":
			    this.deleteUsers(selectedRows);
			    break;
	       }
	       // reset the action menu
	       $	(evt.target).val("takeAction");
	    },
	toggleAllCheckBoxes: function () {
	    
	    $("input:checkbox[id!='selectAllCB']").attr("checked",$("#selectAllCB").is(":checked"));
	    
	    for(var i = 0; i< this.grid.data.length; i++) {
		if ($("input:checkbox#selectAllCB").attr("checked") === "checked") {
		    this.grid.setValueAt(i,0,true,true);
		} else {
		    this.grid.setValueAt(i,0,false,true);
		}
	    }
	},
	
	    // This function contains tasks after the users have been received from the database.
	       // Decorate the Table: 
	      // set the action column to have a cog initially.   Note: this is a hack to get an icon set in the Editable Table
	      // also set the color to green for those users who are logged in.  
	   
	    
	postLoadingTasks: function () {
	    var self = this;
	    for(var i = 0; i < this.grid.getRowCount(); i++)
	    {
			if (this.grid.getRowValues(i).user_id==='') {this.grid.remove(i);}  // this is a hack to remove the row with empty values.
	    }
		
	    $("#users_table tr[id*='UserListTable'] td:nth-child(2)").html("<i class='icon-cog'></i>");
	    _(this.loggedInUsers).each(function(user){
			$("tr#UserListTable_" + user + " td:nth-child(3)").css("color","green").css("font-weight","bold");
	    });
		
	    this.loggedInUsers = [];
	    // Display the number of users shown
	    $("#usersShownInfo").html(this.grid.getRowCount() + " of " + this.collection.length + " users shown.");
		
	    // bind the collection to the Validation.  See Backbone.Validation at https://github.com/thedersen/backbone.validation
	    
	    Backbone.Validation.bind(this,{
		valid: function(view, attr, selector) {
		    //console.log("running valid");
		},
		invalid: function(view, attr, error,selector) {
		    console.log("running invalid");
		    self.error = {errorAttr: attr, errorText: error};
	        }
	    }); 
	  

	},
    render: function(){
    	this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
	    var self = this;  
	    
	    
	    this.$el.append(_.template($("#userListTable").html()));
	    
	    this.$el.append(this.passwordPane = new ChangePasswordView({model: new TempUserList()}));
	    this.$el.append(this.emailPane = new EmailStudentsView({model: new TempUserList()}));
	    return this;
    },
    gridChanged: function(rowIndex, columnIndex, oldValue, newValue) {

    	var self = this;
		
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
		    var cid = self.grid.getRowId(rowIndex);
		    var property = self.grid.getColumnName(columnIndex);
		    var editedModel = self.collection.get(cid);
		    if(property == 'permission'){
				newValue = {name: "", value: newValue};  // Do we need to make sure to set the name correctly too? 
		    }
		    console.log("just before editedModel.set");
		    
		    // The following checks if the data validates.  
		    

		    if(editedModel.preValidate(property, newValue)){
				self.errorPane.appendHTML("There is an error in setting the " + property + " for user " 
							+ editedModel.attributes.user_id + " in the red box below. <br/>  ");
				$("tr#UserListTable_" + cid + " td:nth-child("+(columnIndex+1) + ")").css("background-color","rgba(255,0,0,0.5)");
				
		    } else {
				$("tr#UserListTable_" + cid + " td:nth-child("+(columnIndex+1) + ")").css("background","none");
				self.updatedUser = {user_id: editedModel.attributes.user_id, property: property, oldValue: oldValue, newValue: newValue};
				editedModel.set(property,newValue);
			}
        }
		
    },
	addOne: function(user){
            var userInfo = user.toJSON();
	    userInfo.permission = ""+userInfo.permission.value;  // return only the String version of the Permission
	    this.grid.append(user.cid, userInfo);
	    if (userInfo.login_status==1){
		this.loggedInUsers.push(user.cid);
	    }
        },

        addAll: function(){
	    this.loggedInUsers=[];  // this will store the rows of the users who are currently logged in.  Perhaps this should go elsewhere. 
            var self = this;
            this.collection.each(function(user){self.addOne(user)});
	    this.grid.refreshGrid();
        },
	deleteUsers: function(rows){
	    rowsBackwards = _(rows).sortBy(function (num) { return -1*num;});  // the rows need to be sorted in decreasing order so the rows in the table are
									// removed correctly. 
	    var self = this;
	    var str = "Do you wish to delete the following students: "
	    _(rows).each(function (row) {str += self.grid.getDisplayValueAt(row,4) + " "+ self.grid.getDisplayValueAt(row,5) + " " });
	    var del = confirm(str);
		    
	    if (del){
		_.each(rowsBackwards,function (row){
		    console.log("Remove " + self.grid.getDisplayValueAt(row,2));  // The user_id property is in column 2 
		    var user = self.collection.where({user_id: self.grid.getDisplayValueAt(row,2)})[0];
		    self.collection.remove(user);
			   
		     // Was the deletion successful?  How to test?
		    self.grid.remove(row);
			   
		});
		this.selectedRows=[];
	    }
	},
	changePassword: function(rows){
	    var tempUsers = new TempUserList();
	    var self = this; 
	    _.each(rows, function (row){
		tempUsers.add(self.collection.where({user_id: self.grid.getDisplayValueAt(row,2)})[0]);
	    })
	    this.passwordPane.model=tempUsers;
	    this.passwordPane.render();
	    this.passwordPane.$el.dialog("open");
	    },
	emailStudents: function(rows){
	    var tempUsers = new TempUserList();
	    var self = this; 
	    _.each(rows, function (row){
		tempUsers.add(self.collection.where({user_id: self.grid.getDisplayValueAt(row,2)})[0]);
	    })
	    this.emailPane.model=tempUsers;
	    this.emailPane.render();
	    this.emailPane.$el.dialog("open");
	    },
	messageType: "",   // the type of message shown at the top of the page.     
	
	selectedRows: []  // which rows in the table are selected. 


    });
    
    // This is a Backbone collection of webwork.User(s).  This is different than the webwork.userList class  because we don't need
    // the added expense of additions to the server.
    
    var TempUserList = Backbone.Collection.extend({model:User});
    
//    var userListView = new UserListView();

    var App = new UserListView({el: $("div#main")});
    



	
});


