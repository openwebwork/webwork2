/*  ClasslistManager.js:
   This is the base javascript code for the UserList3.pm (Classlist Manager).  This sets up the View and the classlist object.
  
*/

define(['backbone','views/MainView','models/UserList','config','views/CollectionTableView',
			'../other/AddStudentManView','../other/AddStudentFileView','models/ProblemSetList','views/ModalView',
			'views/ChangePasswordView','views/EmailStudentsView','bootstrap'], 
function(Backbone,MainView,UserList,config,CollectionTableView, AddStudentManView,AddStudentFileView,
				ProblemSetList,ModalView,ChangePasswordView,EmailStudentsView){
var ClasslistView = MainView.extend({
	msgTemplate: _.template($("#classlist-messages").html()),
	initialize: function (options) {
		MainView.prototype.initialize.call(this,options);

		_.bindAll(this, 'render','deleteUsers','changePassword','syncUserMessage','removeUser');  // include all functions that need the this object
		var self = this;
    	
		
		this.addStudentManView = new AddStudentManView({users: this.users,messageTemplate: this.msgTemplate});
	    this.addStudentFileView = new AddStudentFileView({users: this.users,messageTemplate: this.msgTemplate});
	    this.tableSetup();
	    
            
        this.users.on({"add": this.addUser,"change": this.changeUser,"sync": this.syncUserMessage,
    					"remove": this.removeUser});
	    this.userTable = new CollectionTableView({columnInfo: this.cols, collection: this.users, 
                            paginator: {page_size: 10, button_class: "btn btn-default", row_class: "btn-group"}});

	    this.userTable.on("page-changed",function(num){
	    	self.state.set("page_number",num);
	    }).on("table-sorted",function(info){
            self.state.set({sort_class: info.classname, sort_direction: info.direction});
        })
	    this.state.on("change:filter_text", function () {self.filterUsers();});
	    	    
	    $("div#addStudFromFile").dialog({autoOpen: false, modal: true, title: "Add Student from a File",
					    width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
	      

	    // bind the collection to the Validation.  See Backbone.Validation at https://github.com/thedersen/backbone.validation	  
	    this.users.each(function(model){
	    	model.bind('validated:invalid', function(_model, errors) {
			    console.log("running invalid");
			    console.log(errors);
			    var row; 
			    self.$("td.user-id").each(function(i,v){
			    	if($(v).text()===_model.get("user_id")){
			    		row = i;
			    	}
			    })
			    
			    _(_.keys(errors)).each(function(key){
			    	var obj = _(self.userTable.columnInfo).findWhere({key: key});
			    	var col = _(self.userTable.columnInfo).indexOf(obj);
				    self.eventDispatcher.trigger("add-message",{text: errors[key],type: "danger", short: "Validation Error"});
				    self.$("tbody tr:nth-child("+ (row+1) +") td:nth-child("+(col+1)+")")
				    	.css("background-color","rgba(255,0,0,0.25)");
				});
	        });
	    }); 

        this.passwordPane = new ChangePasswordView({users: this.users});
        this.emailPane = new EmailStudentsView({users: this.users}); 
    },

    render: function(){
	    this.$el.html($("#classlist-manager-template").html());
        this.userTable.render().$el.addClass("table table-bordered table-condensed");
        this.$(".users-table-container").append(this.userTable.el);
        // set up some styling
        this.userTable.$(".paginator-row td").css("text-align","center");
        this.userTable.$(".paginator-page").addClass("btn");
      
        this.showRows(this.state.get("page_size"));
        this.filterUsers();
        this.userTable.gotoPage(this.state.get("page_number"));
        MainView.prototype.render.apply(this);
        this.stickit(this.state,this.bindings);

        if(this.state.get("sort_class")&&this.state.get("sort_direction")){
            this.userTable.sortTable({sort_info: this.state.pick("sort_direction","sort_class")});
        }
	    return this;
    },  
    bindings: { ".filter-text": "filter_text"},
    getDefaultState: function () {
        return {filter_text: "", page_number: 0, page_size: this.settings.getSettingValue("ww3{pageSize}") || 10,
                    sort_class: "", sort_direction: ""};
    },
    addUser: function (_user){
    	_user.changingAttributes = {user_added: ""};
    	_user.save();
    },
    changeUser: function(_user){
    	if(_(_user.changingAttributes).has("user_added") || _.keys(_user.changed)[0]==="action"){
    		return;
    	}
    	_user.changingAttributes=_.pick(_user._previousAttributes,_.keys(_user.changed));
    	_user.save();
    },
    removeUser: function(_user){
    	var self = this;
    	_user.destroy({success: function(model){
	    		self.eventDispatcher.trigger("add-message",{type: "success",
            		short: self.msgTemplate({type: "user_removed", opts:{username:_user.get("user_id")}}),
            		text: self.msgTemplate({type: "user_removed_details", opts: {username: _user.get("user_id")}})});
	    		self.render();
    	}});
    },
    syncUserMessage: function(_user){
    	var self = this;
    	_(_user.changingAttributes).chain().keys().each(function(key){
    		switch(key){
                case "user_added":
                	self.eventDispatcher.trigger("add-message",{type: "success",
                		short: self.msgTemplate({type: "user_added", opts:{username:_user.get("user_id")}}),
                		text: self.msgTemplate({type: "user_added_details", opts: {username: _user.get("user_id")}})});
                	self.userTable.render();
                	break;
                default:    
		    	 	self.eventDispatcher.trigger("add-message",{type: "success", 
		                short: self.msgTemplate({type:"user_saved",opts:{username:_user.get("user_id")}}),
		                text: self.msgTemplate({type:"user_saved_details",opts:{username:_user.get("user_id"),
		                	key: key, oldValue: _user.changingAttributes[key], newValue: _user.get(key)}})});
	    	}
    	});
   },

    // I think some of these should go into EditGrid.js
    events: {
	    "click .add-students-file-option": "addStudentsByFile",
	    "click .add-students-man-option": "addStudentsManually",
	    "click .export-students-option": "exportStudents",
		'keyup input.filter-text' : 'filterUsers',
	    'click button.clear-filter-button': 'clearFilterText',
	    'change .user-action': 'takeAction',
	    "click a.email-selected": "emailSelected",
	    "click a.password-selected": "changedPasswordSelected",
	    "click a.delete-selected": "deleteSelectedUsers",
	    "change th[data-class-name='select-user'] input": "selectAll",
	    "click a.show-rows": "showRows"
	},
	addStudentsByFile: function () {
		this.addStudentFileView.openDialog();
	},
	addStudentsManually: function () {
		this.addStudentManView.openDialog();
	},
	exportStudents: function () {
	    var textFileContent = "";
	    textFileContent += _(config.userProps).map(function (prop) { return "\"" + prop.longName + "\"";}).join(",") + "\n";
	    
        // Write out the user Props
        this.users.each(function(user){
        	textFileContent += user.toCSVString();
	    });

        var _mimetype = "text/csv";
	    var blob = new Blob([textFileContent], {type:_mimetype});
        var _url = URL.createObjectURL(blob);
        var _filename = config.courseSettings.course_id + "-classlist-" + moment().format("MM-DD-YYYY") + ".csv";
        var modalView = new ModalView({template: $("#export-to-file-template").html(), 
        	templateOptions: {url: _url, filename: _filename, mimetype: _mimetype}});
        modalView.render().open();
	},	
	filterUsers: function () {
        this.userTable.filter(this.state.get("filter_text")).render();
        if(this.state.get("filter_text").length>0){
            this.state.set("page_number",0);
        }
        this.$(".num-users").html(this.userTable.getRowCount() + " of " + this.problemSets.length + " users shown.");
    },
    clearFilterText: function () {
        this.state.set("filter_text","");
    },
	selectAll: function (evt) {
		this.$("td:nth-child(1) input[type='checkbox']").prop("checked",$(evt.target).prop("checked"));
	},
    showRows: function(evt){
        this.state.set("page_size", _.isNumber(evt) || _.isString(evt) ? parseInt(evt) : $(evt.target).data("num"));
        this.$(".show-rows i").addClass("not-visible");
        this.$(".show-rows[data-num='"+this.state.get("page_size")+"'] i").removeClass("not-visible")
        if(this.state.get("page_size") < 0) {
            this.userTable.set({num_rows: this.users.length});
        } else {
            this.userTable.set({num_rows: this.state.get("page_size")});
        }
    },
	tableSetup: function () {
            var self = this;
            this.cols = [{name: "Select", key: "select_row", classname: "select-user", 
                stickit_options: {update: function($el, val, model, options) {
                    $el.html($("#checkbox-template").html());
                }}, colHeader: "<input type='checkbox'></input>"},
                {name: "Login Name", key: "user_id", classname: "login-name", datatype: "string"},
                {name: "Assigned Sets", key: "assigned_sets", classname: "assigned-sets", datatype: "integer",
                	value: function(model){
                		return self.problemSets.filter(function(_set) { 
                				return _(_set.get("assigned_users")).indexOf(model.get("user_id"))>-1;}).length;
               		},
                	stickit_options: {update: function($el, val, model, options) {
                		$el.html(self.problemSets.filter(function(_set) { 
                				return _(_set.get("assigned_users")).indexOf(model.get("user_id"))>-1;}).length + "/"
                		+ self.problemSets.size()); }
                }},
                {name: "First Name", key: "first_name", classname: "first-name", editable: true, datatype: "string",
	            	stickit_options: {events: ['blur']}},
                {name: "Last Name", key: "last_name", classname: "last-name", editable: true, datatype: "string",
            		stickit_options: {events: ['blur']}},
                {name: "Email", key: "email_address", classname: "email",  editable: true, datatype: "string",
            		stickit_options: {events: ['blur']}},
                {name: "Student ID", key: "student_id", classname: "student-id",  editable: true, datatype: "string",
            		stickit_options: {events: ['blur']}},
                {name: "Status", key: "status", classname: "status",  editable: true, datatype: "string",
            		stickit_options: {events: ['blur']}},
                {name: "Section", key: "section", classname: "section",  editable: true, datatype: "string",
            		stickit_options: {events: ['blur']}},
            	{name: "Recitation", key: "recitation", classname: "recitation",  editable: true, datatype: "string",
            		stickit_options: {events: ['blur']}},
            	{name: "Comment", key: "comment", classname: "comment",  editable: true, datatype: "string",
            		stickit_options: {events: ['blur']}},
            	{name: "Permission", key: "permission", classname: "permission",
            		stickit_options: { selectOptions: { 
            			collection: [{value: "-5", label: "guest"},
            				{value: "0", label: "Student"},
            				{value: "2", label: "login proctor"},
            				{value: "3", label: "grade proctor"},
            				{value: "5", label: "T.A."},
            				{value: "10", label: "Professor"},
            				{value: "20", label: "Admininistrator"}]}}
            }];
	},
	getSelectedUsers: function () {
		var self = this;
		return $("tbody td:nth-child(1) input[type='checkbox']:checked").map(function(i,v) { 
				return self.users.findWhere({user_id: $(v).closest("tr").children("td.login-name").text()}); 
			});
	}, 
	deleteSelectedUsers: function(){
		this.deleteUsers(this.getSelectedUsers());
	},
	deleteUsers: function(_users){ // need to put the string below in the template file
		if(_users.length === 0){
			alert("You haven't selected any users to delete.");
			return;
		}
		var self = this
	    	, str = "Do you wish to delete the following students: " + 
	    			_(_users).map(function (user) {return user.get("first_name") + " "+ user.get("last_name")}).join(", ")
		    , del = confirm(str);
	    if (del){
	    	self.users.remove($.makeArray(_users));
			this.userTable.render();
	    }
	},
	changedPasswordSelected: function(){
		alert("Changing Passwords isn't implemented yet.")
	},
	changePassword: function(rows){
		this.passwordPane.users=this.getUsersByRows(rows);
	    this.passwordPane.render();
	    this.passwordPane.$el.dialog("open"); 
	    },
	emailSelected: function(){
		alert("Emailing students is not implemented yet");
	},
	emailStudents: function(rows){
	    this.emailPane.users = this.getSelectedUsers();
	    this.emailPane.render();
	    this.emailPane.$el.dialog("open");
    }, 
    getHelpTemplate: function (){
    	return $("#classlist-help-template").html();
    }
});

return ClasslistView;
    
});


