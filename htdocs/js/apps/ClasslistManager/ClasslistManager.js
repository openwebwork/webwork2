/*  ClasslistManager.js:
   This is the base javascript code for the UserList3.pm (Classlist Manager).  This sets up the View and the classlist object.
  
*/

define(['module','Backbone','views/WebPage','models/UserList','views/EditGrid','config','AddStudentManView',
			'AddStudentFileView','views/ChangePasswordView','views/EmailStudentsView','bootstrap'], 
function(module,Backbone,WebPage,UserList,EditGrid,config,AddStudentManView,AddStudentFileView,
				ChangePasswordView,EmailStudentsView){
var ClasslistManager = WebPage.extend({
	initialize: function () {
		this.constructor.__super__.initialize.apply(this, {el: this.el});
		_.bindAll(this, 'render','deleteUsers','changePassword','gridChanged');  // include all functions that need the this object
		var self = this;
    	
		// this.collection is a UserList 

    	this.collection = (module.config().users) ? new UserList(module.config().users) : new UserList();

    	// call .parse on each user to mimic a fetch call, so it appears each user exists. (id is set)
    	this.collection.each(function(user){ user.parse(); });
    	this.messages=[];

        this.editgrid = new EditGrid({grid_name: "users-table-container", table_name: "users-table",
        paginator_name: "#users-table-paginator", template_name: "#classlist-table-template",
        enableSort: true, pageSize: 10});
        
        this.editgrid.grid.load({metadata: config.userTableHeaders});
        this.customizeGrid();
        this.editgrid.grid.modelChanged = this.gridChanged;
	    this.addStudentManView = new AddStudentManView({users: this.collection});
	    this.addStudentFileView = new AddStudentFileView({users: this.collection});
	    this.render();
            
	    this.collection.on('add',function(user){
	    	self.editgrid.grid.append(user.cid, user.toJSON());
	    	self.editgrid.updatePaginator();
	    	self.announce.addMessage({text: "The user with id " + user.get("user_id") + " has been added."});
	    });

	    this.collection.on('sync',function(model, resp, options){
	    	var msg = _(self.messages).findWhere({user_id: model.get("user_id")});
	    	var index = _(self.messages).indexOf(msg);
	    	self.messages.splice(index,1);
	    	self.announce.addMessage({text: "The property " + msg.property + " of user " + model.get("user_id") + 
	    		" changed from " + msg.oldValue + " to " + msg.newValue});
	    });	   

	    	    
	    $("div#addStudFromFile").dialog({autoOpen: false, modal: true, title: "Add Student from a File",
					    width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
	     

	    // Make sure the take Action menu item is reset
	    $("button#help-link").click(function () {self.helpPane.open();});	  

	    _(this.loggedInUsers).each(function(user){
			$("tr#UserListTable_" + user + " td:nth-child(3)").css("color","green").css("font-weight","bold");
	    });
		
	    this.loggedInUsers = [];
	    // Display the number of users shown
	    $("#usersShownInfo").html(this.editgrid.grid.getRowCount() + " of " + this.collection.length + " users shown.");
		
	    // bind the collection to the Validation.  See Backbone.Validation at https://github.com/thedersen/backbone.validation
	  
	    this.collection.each(function(model){
	    	model.bind('validated:invalid', function(_model, errors) {
			    console.log("running invalid");
			    console.log(errors);
			    console.log(_model);
			    _(_.keys(errors)).each(function(key){
				    self.errorPane.addMessage({text: errors[key]});
				});
	        });
	    }); 

    },

    render: function(){
    	this.$el.empty();
    	this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
	    
    	this.$el.append($("#classlist-manager-template").html());
    	this.editgrid.setElement($("#users-table-container"));
        this.editgrid.render();
        this.updateGrid();
	    this.$(".num-users").html(this.editgrid.grid.getRowCount() + " of " + this.collection.length + " users shown.");
	    this.$el.append(this.passwordPane = new ChangePasswordView());
	    this.$el.append(this.emailPane = new EmailStudentsView()); 
	    return this;
    },

    // I think some of these should go into EditGrid.js
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
	    //var bb = new BlobBuilder;
	    
	    // Write the headers out
	    bb.append((_(config.userProps).map(function (prop) { return "\"" + prop.longName + "\"";})).join(",") + "\n");
	    
        // Write out the user Props
        this.collection.each(function(user){bb.append(user.toCSVString())});
	    
        // need a more appropriate filename

        saveAs(bb.getBlob("text/csv;charset=utf-8"), "hello world.csv");            
	},	
	updateGrid: function (){
        var _data = this.collection.map(function(user) { return {id: user.cid, values: user.attributes};});
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
		   
		}
		
		// check to make sure that the updated information needs to be sent to the server
		
		else if (oldValue !== newValue  ){
			var grid = this.editgrid.grid;
		    var cid = grid.getRowId(rowIndex);
		    var property = grid.getColumnName(columnIndex);
		    var editedModel = this.collection.get(cid);
		    console.log("just before editedModel.set");
		    
		    
			var result = editedModel.save(property,newValue);
			if(result){  // if it validates
				$("tr#UserListTable_" + cid + " td:nth-child("+(columnIndex+1) + ")").css("background","none");	
				this.messages.push({user_id: editedModel.get("user_id"), property: property, oldValue: oldValue, newValue: newValue});
			} 
        }
		
    },
	filterUsers: function (evt) {
	    this.editgrid.grid.filter($("#filter").val());
	    this.$(".num-users").html(this.editgrid.grid.getRowCount() + " of " + this.collection.length + " users shown.");
	},
	clearFilterText: function () {
		$("input#filter").val("");
		this.editgrid.grid.filter("");
		this.$(".num-users").html(this.editgrid.grid.getRowCount() + " of " + this.collection.length + " users shown.");
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
			return self.collection.get($("#users-table table tr:nth-child(" +(_row+1) + ")").attr("id").split("users-table-container_")[1]);
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
			_(users).each(function(user){self.collection.remove(user);});

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
    }
});

    
//    var userListView = new UserListView();

var App = new ClasslistManager({el: $("div#main")});
    



	
});


