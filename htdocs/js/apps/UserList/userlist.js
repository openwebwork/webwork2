/*  userlist.js:
   This is the base javascript code for the UserList3.pm (Classlist Editor3).  This sets up the View and the classlist object.
  
  You must include the User.js code before this in order to user the UserList class. 
*/

var userList;
var App;

$(function(){

    // get usernames and keys from hidden variables and set up webwork object:
    var myUser = document.getElementById("hidden_user").value;
    var mySessionKey = document.getElementById("hidden_key").value;
    var myCourseID = document.getElementById("hidden_courseID").value;
    // check to make sure that our credentials are available.
    if (myUser && mySessionKey && myCourseID) {
        webwork.requestObject.user = myUser;
        webwork.requestObject.session_key = mySessionKey;
        webwork.requestObject.courseID = myCourseID;
    } else {
        alert("missing hidden credentials: user "
            + myUser + " session_key " + mySessionKey
            + " courseID" + myCourseID, "alert-error");
    }

    var UserListView = Backbone.View.extend({
        initialize: function(){
	    _.bindAll(this, 'render');
	    
	    this.users = new webwork.UserList();  // This is a Backbone.Collection of users
	    
	    this.grid = new EditableGrid("UserListTable", { enableSort: true});

            this.grid.load({ metadata: [
                { name: "Select", datatype: "boolean", editable: true},
		{ name: "Take Action", datatype: "string", editable: true,
                    values: {"action0":"Take Action","action1":"Change Password",
                        "action2":"Delete User","action3":"Act as User",
                        "action4":"Student Progess","action5":"Email Student"}
                },
                { label: "Login Name", name: "user_id", datatype: "string", editable: false },
                { name: "Login Status", datatype: "string", editable: false },
                { name: "Assigned Sets", datatype: "integer", editable: false },
                { label: "First Name", name: "first_name", datatype: "string", editable: true },
                { label: "Last Name", name:"last_name", datatype: "string", editable: true },
                { label: "Email Address", name: "email_address", datatype: "string", editable: true },
                { label: "Student ID", name: "student_id", datatype: "string", editable: true },
                { label: "Status", name: "status", datatype: "string", editable: true,
                    values : {
                        "en":"Enrolled",
                        "noten":"Not Enrolled"
                    }
                },
                { label: "Section", name: "section", datatype: "integer", editable: true },
                { label: "Recitation", name: "recitation", datatype: "integer", editable: true },
                { label: "Comment", name: "comment", datatype: "string", editable: true },
                { label: "Permission Level", name: "permission", datatype: "integer", editable: true,
                    values : {
                        "-5":"guest","0":"Student","2":"login proctor",
                        "3":"grade proctor","5":"T.A.", "10": "Professor",
                        "20":"Admininistrator"
		    }
		}
		
		// The following gives a blank row which we remove in this.render() below.  Not sure why we need a blank row
		// but won't work without it.    
		
            ], data: [{id:0, values:{}}]});
	    //] });
	    
	    
	    this.render();
	    
	    this.grid.renderGrid('users_table', 'usersTableClass', 'userTable');
	    
	    
	    this.users.fetch();
	    
	    this.grid.refreshGrid();
	    
	    var self = this;
	    
	    this.grid.modelChanged = function(rowIndex, columnIndex, oldValue, newValue) {
		
		
		// keep track of the selected rows. 
		
		if (columnIndex == 0)
		{
		    if (newValue) self.selectedRows.push(rowIndex);
		    else self.selectedRows = _.reject(self.selectedRows, function (num) { return num == rowIndex;}); 
		} else if (columnIndex == 1 )  // the takeAction column has been selected.
		{
		    
		   switch (newValue){
		    case "action1":  // Change Password
		    break;
		    case "action2":  // deleteUser
		    self.deleteUsers([rowIndex]);
		    
		    break;
		    case "action3":  // Act as User
		    break;
		    case "action4":  // Student Progress
		    break;
		    case "action5":  // Email Student
		    break;
		
		    
		   }
		}
		
		// check to make sure that the updated information needs to be sent to the server
		
		else if (oldValue != newValue  ){
		    var cid = self.el.getRowId(rowIndex);
		    var property = self.el.getColumnName(columnIndex);
		    var editedModel = self.model.getByCid(cid);
		    if(property == 'permission'){
			newValue = {name: "", value: newValue};
		    }
		    editedModel.set(property, newValue);
		    this.updateUser();
                }
		
	    };
	    
	    // Resets the grid by deleting all rows and readding.  
	    
            this.users.on('reset', function(){
                while(self.grid.getRowCount() > 1){
                    self.grid.remove(1);
                }
                self.addAll();
		if (this.grid.getRowValues(0).user_id=='') {this.grid.remove(0);}  // this is a hack to remove the row with empty values. 
            }, this);
            //this.users.on('all', this.render, this);
            
	    this.users.on('add',this.addOne,this);
	    
	    // Setup the Add Student Wizard Dialog
	    $("div#addStudDialog").dialog({autoOpen: false, modal: true, title: "Add Student Wizard", width: 300,
					  buttons: {"From a File":  function () { $("div#addStudDialog").dialog("close"); self.addStudentsFromFile()},
					  "By Hand": function () {$("div#addStudDialog").dialog("close");self.addStudentsManually()},
					  "Cancel": function () {$("div#addStudDialog").dialog("close");} }});
	    
	    $("div#addStudFromFile").dialog({autoOpen: false, modal: true, title: "Add Student from a File",
					    width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
	    
	    // Open the Add Student Wizard
	    $("input#addStudentButton").click(function() {$("div#addStudDialog").dialog("open");});
	    //$("input#testButton").click(function () {self.model.trigger("addstudent")});
	    
	    // Make sure the take Action menu item is reset
	    $("select#mainActionMenu").val("takeAction");
	    
        },
        events: {
	    'change select#mainActionMenu' : 'takeBulkAction',
	    'change input#selectAllCB' : 'toggleAllCheckBoxes',
	    'keyup input#filter' : 'filterUsers',
	    
	},
	filterUsers: function (evt) {this.grid.filter($("#filter").val()) },
	takeBulkAction: function (evt) { switch (evt.target.value){
	        //console.log($(this));
		case "menuEmail":
		    break;
		case "menuChangePassword":
		    break;
		case "menuDelete":
		    this.deleteUsers(this.selectedRows);
		    this.selectedRows = []; 
		    break;
	       }
	       // reset the action menu
	       var targ = $(evt.target);
	       console.log(targ);
	       targ.val("takeAction");
	    },
	toggleAllCheckBoxes: function () {$("input:checkbox[id!='selectAllCB']").attr("checked",$("#selectAllCB").is(":checked"));},
	addStudentsFromFile :  function () { var addStudFileDialog = new AddStudentFileView(); addStudFileDialog.openDialog(); },
	addStudentsManually : function () {  var addStudManDialog = new AddStudentManView(); addStudManDialog.openDialog(); },
        render: function(){
	    
	    this.$el.html(_.template($("#mainClasslist").html()));
	    
	    
            //
	    
	    // This is hack to remove the top blank line in the grid.  See above in el.load()
	    
	    

        },

        addOne: function(user){
            var userInfo = user.toJSON();
	    userInfo.permission = ""+userInfo.permission.value;  // return only the String version of the Permission
	    this.grid.append(user.cid, userInfo);
        },

        addAll: function(){
	    console.log("in addAll");
            var self = this;
            this.users.each(function(user){self.addOne(user)});
	    this.grid.refreshGrid();
        },
	deleteUsers: function(rows){
	    rows = _(rows).sortBy(function (num) { return -1*num;});  // the rows need to be sorted in decreasing order so the rows in the table are
									// removed correctly. 
	    var self = this;
	    console.log("Deleting selected users");
	    var str = "Do you wish to delete the following students: "
	    _(rows).each(function (row) {str += self.grid.getDisplayValueAt(row,5) + " "+ self.grid.getDisplayValueAt(row,6) + " " });
	    var del = confirm(str);
		    
	    if (del){
		_.each(rows,function (row){
		    console.log("Remove " + self.grid.getDisplayValueAt(row,2));  // The user_id property is in column 2 
		    var user = self.users.where({user_id: self.grid.getDisplayValueAt(row,2)})[0];
		    self.users.remove(user);
			   
		     // Was the deletion successful?  How to test?
		    self.grid.remove(row);
			   
		});
	    }
    }	,
	
	selectedRows: []


    });
    
    // This is a Backbone collection of webwork.User(s).  This is different than the webwork.userList class  because we don't need
    // the added expense of additions to the server.
    
    var TempUserList = Backbone.Collection.extend({model:webwork.User});
    
    // This the view class of the Add Students Manually for a row of the table. 
    
    var UserRowView = Backbone.View.extend({
	tagName: "tr",
	className: "userRow",
	initialize: function(){
	    _.bindAll(this, 'render','unrender','updateProp','deleteUser'); // every function that uses 'this' as the current object should be in here
	    this.model.bind('remove', this.unrender);
	    //this.model.bind('error',function (model,error) { console.log(model);console.log(error);});
	    this.render();
	},
	events: {
	    'change input': 'updateProp',
	    'click button.deleteUser': 'deleteUser'
	},
	render: function(){
	    var self = this;
	    self.$el.append("<td><button class='deleteUser'>Delete</button></td>");
	    _.each(webwork.userProps, function (prop){self.$el.append("<td><input type='text' size='10' class='input-for-" + prop.shortName + "'></input></td>"); });
	    return this; // for chainable calls, like .render().el
	},
       updateProp: function(evt){
	    var changedAttr = evt.target.className.split("for-")[1];
	    this.model.set(changedAttr,evt.target.value);
	    console.log("new value: " + evt.target.value);
	},
	unrender: function(){
	    this.$el.remove();
	},
	deleteUser: function() {console.log("in deleteUser"); this.model.destroy();}
    });
	
    // This is the View for the dialog for addings students manually    
	
    var AddStudentManView = Backbone.View.extend({
	tagName: "div",
	id: "addStudManDialog",
    
	initialize: function(){
	    _.bindAll(this, 'render','importStudents','addStudent','appendRow'); // every function that uses 'this' as the current object should be in here
	    this.users = new TempUserList();
	    this.users.bind('add', this.appendRow);
	    this.render();
	    
	    for(var i = 0; i<1; i++) {this.users.add(new webwork.User())}  // add a single blank line. 
	    
	    this.$el.dialog({autoOpen: false, modal: true, title: "Add Students by Hand",
						width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
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
	    var tableHTML = $('#manStudentTableTmpl').html();
	    this.$el.html(this.template({content: tableHTML}));
	    _(this.users).each(function(user){ self.appendRow(user);}, this);
	},
	importStudents: function(){  // validate each student data then upload to the server.
	    console.log('in importStudents');
	    _(this.users.models).each(function(user){
		App.users.add(user);
		console.log("Adding the following student: " + JSON.stringify(user))
	    });
	    this.closeDialog();
	    
	},
	appendRow: function(user){
	    var tableRow = new UserRowView({model: user});
	    $("table#man_student_table tbody",this.el).append(tableRow.el);
	},
	addStudent: function (){ this.users.add(new webwork.User());}
    });
	
	
	
    var AddStudentFileView = Backbone.View.extend({
	tagName: "div",
	id: "addStudFileDialog",
    
	initialize: function(){
	    _.bindAll(this, 'render','importStudents','addStudent','appendRow'); // every function that uses 'this' as the current object should be in here
	    this.users = new TempUserList();
	    this.render();
	    
	    //for(var i = 0; i<1; i++) {this.users.add(new webwork.User())}  // add a single blank line. 
	    
	    this.$el.dialog({autoOpen: false, modal: true, title: "Add Students from a File",
						width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
	},
	events: {
	    "click button#importStudFromFileButton": "importStudents",
	    "change input#files": "readFile",

	},
	openDialog: function () { this.$el.dialog("open");},
	closeDialog: function () {this.$el.dialog("close");},
	render: function(){
	    var self = this;
//	    console.log(this.template({}));
	    this.$el.html($("#add_student_file_dialog_content").html());
	},
	readFile: function(evt){
	    console.log("in loadFile");
	    $("li#step1").css("display","none");  // Hide the first step of the Wizard
	    $("li#step2").css("display","block");  // And show the next step.
	    $("button#importStudFromFileButton").css("display","block");
		
	    this.file = $("#files").get(0).files[0];
	    $('#list').html('<em>' + escape(this.file.name));  //+  '(' +  (self.file.type || 'n/a') + ') - ' + 
		//this.file.size +  ' bytes, last modified: ' +
		// (this.file.lastModifiedDate ? this.file.lastModifiedDate.toLocaleDateString() : 'n/a') + '</em>');
        
	    // Need to test if the browser can handle this new object.  If not, find alternative route.
	
	    var reader = new FileReader();
        
	    reader.onload = function(event) {
		var content = event.target.result;
		var str = util.fillHTMLTableFromArray(util.CSVToArray(content),
							  ["","Login Name","First Name","Last Name","Email","Student ID","Status",
							    "Section","Recitation","Comment","Permission Level","Password"]);
		    
		$("#studentTable").html(str);
        
		$("#selectAllASW").click(function(){ $(".selRow").attr("checked",$("#selectAllASW").is(":checked")); });
		
		console.log("loaded file");
	    } 
		    
	    reader.readAsText(this.file);
		
		
	},
	importStudents: function () {
	    // First check to make sure that the headers are not repeated.
	    var headers = [];
	    _($("select[class='colHeader']")).each(function(obj,j){if ($(obj).val() != "") headers.push({header: $(obj).val(), position: j});});
	    
	    //console.log(headers);
	    var heads = _(headers).map(function (obj) {return obj.header;});
	    var sortedHeads = _(heads).sortBy(function (str) {return str;});
	    
	    //console.log(heads);
	    
	    var validHeaders=true;
	    for (var i=0;i<sortedHeads.length-1;i++){if(sortedHeads[i]==sortedHeads[i+1]) {validHeaders=false; break;}};
	    if (!validHeaders) {alert("Each Column must have a unique Header.");  return false;}
	    
	    // This is an array of the column numbers that the headers are in.  I think this can be done in a more efficient way. 
	    
	    var headCols = _.map(headers, function (value,j) { return _.find(_.map($("select.colHeader"),function (val,i) {if (val.value==value) return i;}), function (num) { return typeof num === 'number' && num % 1 == 0; })});
	    
	    // Determine the rows that have been selected.
	    
	    var rows = _.map($("input.selRow:checked"),function(val,i) {return parseInt(val.id.split("row")[1]);});
	    _.each(rows, function(row){
		var user = new webwork.User();
		_.each(headers, function(obj){
			for(var i = 0; i < webwork.userProps.length; i++)
			{
			    // set the appropriate user property given the element in the table. 
			   if(obj.header==webwork.userProps[i].longName) {user.set(webwork.userProps[i].shortName,$.trim($("tr#row"+row+" td.column" + obj.position).html()))}
			}
		    });
		//this.users.add(u);
		
		App.users.add(user);
	    });

	this.closeDialog();    
    }
	,
	appendRow: function(user){
	    var tableRow = new UserRowView({model: user});
	    $("table#man_student_table tbody",this.el).append(tableRow.el);
	},
	addStudent: function (){ this.users.add(new webwork.User());}
    });
	


    App = new UserListView({el: $("div#mainDiv")});
    // then we attach to the HTML table and render it
    //editableGrid.attachToHTMLTable('cltable');


    //userList.fetch();
    /*var users = new Array();
    for(var i = 0; i < editableGrid.getRowCount(); i++){
        var atts = editableGrid.getRowValues(i);
        delete atts['Take Action'];
        console.log(atts);
        users.push(atts);
    }
    userList.reset(users, {silent: true});*/
    
	
});


