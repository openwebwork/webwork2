/*  ClasslistManager.js:
   This is the base javascript code for the UserList3.pm (Classlist Manager).  This sets up the View and the classlist object.
  
*/

define(['backbone','views/MainView','models/UserList','config','views/CollectionTableView',
			'../other/AddStudentManView','../other/AddStudentFileView','models/ProblemSetList','views/ModalView',
			'views/ChangePasswordView','views/EmailStudentsView','config','bootstrap'], 
function(Backbone,MainView,UserList,config,CollectionTableView, AddStudentManView,AddStudentFileView,
				ProblemSetList,ModalView,ChangePasswordView,EmailStudentsView,config){
var ClasslistView = MainView.extend({
	msgTemplate: _.template($("#classlist-messages").html()),
	initialize: function (options) {
		MainView.prototype.initialize.call(this,options);

		_.bindAll(this, 'render','deleteUsers','changePassword','syncUserMessage','removeUser');  // include all functions that need the this object
		var self = this;
    	
		this.addStudentManView = new AddStudentManView({users: this.users,messageTemplate: this.msgTemplate});
	    this.addStudentFileView = new AddStudentFileView({users: this.users,messageTemplate: this.msgTemplate});
	    this.addStudentManView.on("modal-opened",function (){
            self.state.set("man_user_modal_open",true);
        }).on("modal-closed",function(){
            self.state.set("man_user_modal_open",false);
            self.render(); // for some reason the checkboxes don't stay checked. 
        })

        this.tableSetup();
	    
            
        this.users.on({"add": this.addUser,"change": this.changeUser,"sync": this.syncUserMessage,
    					"remove": this.removeUser});
	    this.userTable = new CollectionTableView({columnInfo: this.cols, collection: this.users, row_id_field: "user_id",
                            paginator: {page_size: 10, button_class: "btn btn-default", row_class: "btn-group"}});

	    this.userTable.on({
            "page-changed": function(num){ 
                self.state.set("current_page",num);
                self.update();},
	        "table-sorted": function(info){
                self.state.set({sort_class: info.classname, sort_direction: info.direction});},
            "selected-row-changed": function(rowIDs){
                self.state.set({selected_rows: rowIDs});
        }});

	    this.state.on("change:filter_string", function () {self.filterUsers();});
	    	    
	    $("div#addStudFromFile").dialog({autoOpen: false, modal: true, title: "Add Student from a File",
					    width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
	      

	    // bind the collection to the Validation.  See Backbone.Validation at https://github.com/thedersen/backbone.validation	  
	    this.users.each(function(model){
	    	model.bind('validated:invalid', function(_model, errors) {
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

        // query the server every 15 seconds (parameter?) for login status only when the View is visible
        this.eventDispatcher.on("change-view",function(viewID){
        	if(viewID==="classlist"){
        		self.checkLoginStatus();
        	} else {
        		self.stopLoginStatus();
        	}
        })
    },
    render: function(){
	    this.$el.html($("#classlist-manager-template").html());
        this.userTable.render().$el.addClass("table table-bordered table-condensed");
        this.$(".users-table-container").append(this.userTable.el);
        // set up some styling
        this.userTable.$(".paginator-row td").css("text-align","center");
        this.userTable.$(".paginator-page").addClass("btn");
        
        var opts = this.state.pick("page_size","filter_string","current_page","selected_rows");
        if(this.state.get("sort_class")&&this.state.get("sort_direction")){
            _.extend(opts,{sort_info: this.state.pick("sort_direction","sort_class")});
        }
        this.showRows(this.state.get("page_size"));
        this.userTable.set(opts).updateTable();
        this.stickit(this.state,this.bindings);

        MainView.prototype.render.apply(this);
        if(this.state.get("man_user_modal_open")){
            this.addStudentManView.setElement(this.$(".modal-container")).render();
        }
        this.update();

	    return this;
    },  
    bindings: { ".filter-text": "filter_string"},
    getDefaultState: function () {
        return {filter_string: "", current_page: 0, page_size: this.settings.getSettingValue("ww3{pageSize}") || 10,
                    sort_class: "", sort_direction: "", selected_rows: []};
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
    	if(!_(_.keys(_user.changed)).contains("logged_in")){
	    	_user.save();    		
    	}
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
    events: {
	    "click .add-students-file-option": "addStudentsByFile",
	    "click .add-students-man-option": "addStudentsManually",
	    "click .export-students-option": "exportStudents",
		'keyup input.filter-text' : function(){  
            this.filterUsers();
            this.userTable.render();
            this.update();
        },
	    'click button.clear-filter-button': 'clearFilterText',
	    "click a.email-selected": "emailSelected",
	    "click a.password-selected": "changedPasswordSelected",
	    "click a.delete-selected": "deleteUsers",
	    "click a.show-rows": function(evt){ 
            this.showRows(evt);
            this.userTable.updateTable();
        }
	},
	addStudentsByFile: function () {
		this.addStudentFileView.setElement(this.$(".modal-container")).render();
	},
	addStudentsManually: function () {
		this.addStudentManView.setElement(this.$(".modal-container")).render();
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
        this.userTable.set(this.state.pick("filter_string"));
        if(this.state.get("filter_string").length>0){
            this.state.set("current_page",0);
            this.userTable.updateTable();
        }
        this.$(".num-users").html(this.userTable.getRowCount() + " of " + this.users.length + " users shown.");
    },
    clearFilterText: function () {
        this.state.set("filter_string","");
        this.userTable.set({filter_string: ""}).render();
    },
    update: function (){
        $("tr[data-row-id='profa'] select.permission").attr("disabled","disabled");
    },
    showRows: function(arg){
        this.state.set("page_size", _.isNumber(arg) || _.isString(arg) ? parseInt(arg) : $(arg.target).data("num"));
        this.$(".show-rows i").addClass("not-visible");
        this.$(".show-rows[data-num='"+this.state.get("page_size")+"'] i").removeClass("not-visible")
        this.userTable.set({page_size: this.state.get("page_size") <0 ? this.users.length: this.state.get("page_size")});
    },
	tableSetup: function () {
        var self = this;
        this.cols = [{name: "Select", key: "_select_row", classname: "select-user"},
            {name: "Login Name", key: "user_id", classname: "login-name", datatype: "string",
                editable: false},
            {name: "LS", key: "logged_in",classname:"logged-in-status", datatype: "none", editable: false,
                title: "Logged in status",
                stickit_options: {update: function($el, val, model, options) {
                    $el.html(val?"<i class='fa fa-circle' style='color: green'></i>":"")
                }}
            },
            {name: "Assigned Sets", key: "assigned_sets", classname: "assigned-sets", datatype: "integer",
            	value: function(model){
            		return self.problemSets.filter(function(_set) { 
            				return _(_set.get("assigned_users")).indexOf(model.get("user_id"))>-1;}).length;
           		},
                display: function(val){
                    return val + "/" + self.problemSets.length;
                }
            },
            {name: "First Name", key: "first_name", classname: "first-name", editable: true, datatype: "string",
            	stickit_options: {events: ['blur']}},
            {name: "Last Name", key: "last_name", classname: "last-name", editable: true, datatype: "string",
        		stickit_options: {events: ['blur']}},
            {name: "Email", key: "email_address", classname: "email", sortable: false,
        		stickit_options: {
        			update: function($el,val,model,options){
        				// Perhaps this can go into config.js as a Stickit Handler.
        				// in addition, a lot of this needs to go into templates for I18N
        				var address = (val=="")?$("<span>"):$("<a>").attr("href","mailto:"+val);
                        address.text("email");  // I18N

        				var popoverHTML = "<input class='edit-email' value='"+ val +"'></input>"
        					+ "<button class='close-popover btn btn-default btn-sm'>Save and Close</button>";
        				var edit = $("<a>").attr("href","#").text("edit")
        					.attr("data-toggle","popover")
        					.attr("data-title","Edit Email Address")
        					.popover({html: true, content: popoverHTML})
        					.on("shown.bs.popover",function (){
        						$el.find(".edit-email").focus();
        					});
        				function saveEmail(){
        					model.set("email_address",$el.find(".edit-email").val());
        					edit.popover("hide");
        				}
        				$el.html(address).append("&nbsp;&nbsp;").append(edit);
        				$el.delegate(".close-popover","click",saveEmail);
        				$el.delegate(".edit-email","keyup",function(evt){
        					if(evt.keyCode==13){
        						saveEmail();
        					}
        				})
        			}
        		}},
            {name: "Student ID", key: "student_id", classname: "student-id",  editable: true, datatype: "string",
        		stickit_options: {events: ['blur']}},
            {name: "Status", key: "status", classname: "status", datatype: "string",
                value: function(model){
                    return _(config.enrollment_statuses).findWhere({value: model.get("status")}).label;
                },
        		stickit_options: { selectOptions: { collection: config.enrollment_statuses }}},
            {name: "Section", key: "section", classname: "section",  editable: true, datatype: "string",
        		stickit_options: {events: ['blur']}},
        	{name: "Recitation", key: "recitation", classname: "recitation",  editable: true, datatype: "string",
        		stickit_options: {events: ['blur']}},
        	{name: "Comment", key: "comment", classname: "comment",  editable: true, datatype: "string",
        		stickit_options: {events: ['blur']}},
        	{name: "Permission", key: "permission", classname: "permission", datatype: "string",
                value: function(model){
                    return _(config.permissions).findWhere({value: ""+model.get("permission")}).label;  // the ""+ is needed to stringify the permission level
                },
        		stickit_options: { selectOptions: { collection: config.permissions }}
        }];
	},
	deleteUsers: function(){
		var userIDs = this.userTable.getVisibleSelectedRows();
        console.log(userIDs);
		if(userIDs.length === 0){
			alert("You haven't selected any users to delete.");
			return;
		}
        var usersToDelete = this.users.filter(function(u){ return _(userIDs).contains(u.get("user_id"));});
		var self = this
	    	, str = "Do you wish to delete the following students: " + 
	    			_(usersToDelete).map(function (user) {
                        return user.get("first_name") + " "+ user.get("last_name")}).join(", ")
		    , del = confirm(str);
	    if (del){
	    	this.users.remove(usersToDelete);
			this.userTable.updateTable();
            this.state.set("selected_rows",[]);
	    }
	},
	checkLoginStatus: function () {
		var self = this;
		this.loginStatusTimer = window.setInterval(function(){
	        $.ajax({url: config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/loginstatus",
                type: "GET",
                success: function(data){
                	_(data).each(function(st){
                		var user = self.users.findWhere({user_id: st.user_id});
                		user.set("logged_in",st.logged_in);
                	})
                }});

		}, 15000);
	},
	stopLoginStatus: function(){
		window.clearTimeout(this.loginStatusTimer);
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
	    this.emailPane.users = this.state.get("selected_rows")
	    this.emailPane.render();
	    this.emailPane.$el.dialog("open");
    }, 
    getHelpTemplate: function (){
    	return $("#classlist-help-template").html();
    }
});

return ClasslistView;
    
});


