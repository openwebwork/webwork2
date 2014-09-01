/*  ClasslistManager.js:
   This is the base javascript code for the UserList3.pm (Classlist Manager).  This sets up the View and the classlist object.
  
*/

define(['backbone','views/MainView','models/UserList','models/User','config','views/CollectionTableView',
			'models/ProblemSetList','views/ModalView',
			'views/ChangePasswordView','views/EmailStudentsView','config','apps/util','moment','bootstrap'], 
function(Backbone,MainView,UserList,User,config,CollectionTableView,
				ProblemSetList,ModalView,ChangePasswordView,EmailStudentsView,config,util,moment){
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
                self.update();
            },
	        "table-sorted": function(info){
                self.state.set({sort_class: info.classname, sort_direction: info.direction});
            },
            "selected-row-changed": function(rowIDs){
                self.state.set({selected_rows: rowIDs});
            },
            "table-changed": function(){  // I18N
                self.$(".num-users").html(self.userTable.getRowCount() + " of " + self.users.length + " users shown.");
            }
        });

	    this.state.on("change:filter_string", function () {
            self.state.set("current_page",0);
            self.userTable.set(self.state.pick("filter_string","current_page"));
            self.userTable.updateTable();
        });
    
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
	    var textFileContent = _(config.userProps).map(function (prop) { return "\"" + prop.longName + "\"";}).join(",") + "\n";
	    
        // Write out the user Props
        this.users.each(function(user){
        	textFileContent += user.toCSVString();
	    });

        var _mimetype = "text/csv";
	    var blob = new Blob([textFileContent], {type:_mimetype});
        var _url = URL.createObjectURL(blob);
        var _filename = config.courseSettings.course_id + "-classlist-" + moment().format("MM-DD-YYYY") + ".csv";
        var body = _.template($("#export-to-file-template").html(),{url: _url, filename: _filename});
        var modalView = new ModalView({
            modal_size: "modal-lg",
            modal_buttons: $("#close-button-template").html(),
            modal_header: "Export Users",
            modal_body: body});
        this.$el.append(modalView.render().el);
        //modalView.render().open();
	},	
    clearFilterText: function () {
        this.state.set("filter_string","");
    },
    update: function (){
        $("tr[data-row-id='profa'] select.permission").attr("disabled","disabled");
    },
    showRows: function(arg){
        this.state.set("page_size", _.isNumber(arg) || _.isString(arg) ? parseInt(arg) : $(arg.target).data("num"));
        this.$(".show-rows i").addClass("not-visible");
        this.$(".show-rows[data-num='"+this.state.get("page_size")+"'] i").removeClass("not-visible");
        this.userTable.set({page_size: this.state.get("page_size")});
    },
	tableSetup: function () {
        var self = this;
        this.cols = [{name: "Select", key: "_select_row", classname: "select-user"},
            {name: "Login Name", key: "user_id", classname: "login-name", datatype: "string",
                editable: false},
            {name: "LS", key: "logged_in",classname:"logged-in-status", datatype: "none", editable: false,
                title: "Logged in status", searchable: false,
                stickit_options: {update: function($el, val, model, options) {
                    $el.html(val?"<i class='fa fa-circle' style='color: green'></i>":"")
                }}
            },
            {name: "Assigned Sets", key: "assigned_sets", classname: "assigned-sets", datatype: "integer",
                searchable: false, 
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
                search_value: function(model){
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
                search_value: function(model){
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

var AddStudentManView = ModalView.extend({
    initialize: function(options){
        var self=this;
        _.bindAll(this, 'render','saveAndClose','saveAndAddStudent'); // every function that uses 'this' as the current object should be in here
        _(this).extend(_(options).pick("users","messageTemplate"));
        this.collection = new UserList();
        this.model = new User();
        this.invBindings = _.extend(_.invert(_.omit(this.bindings,".permission")),
            {"user_id": ".user-id", "email_address": ".email"});
        _(options).extend({
            modal_size: "modal-lg",
            modal_header: "Add Users to Course",
            modal_body: $("#manual-import-template").html(),
            modal_buttons: $("#manual-import-buttons").html()
        })
        this.setValidation();
        ModalView.prototype.initialize.apply(this,[options]);
    },
    childEvents: {
        "click .action-button": "saveAndClose",
        "click .add-more-button": "saveAndAddStudent",
    },
    setValidation: function (){
        var self = this;
        Backbone.Validation.bind(this, {
            invalid: function(view,attr,error){
                self.$(self.invBindings[attr]).popover("destroy")
                    .popover({placement: "right", content: error})
                    .popover("show").addClass("error");
            },
            valid: function(view,attr){
                self.$(self.invBindings[attr]).popover("destroy").removeClass("error");
            }
        });
    },
    render: function(){
        ModalView.prototype.render.apply(this);
        this.stickit();
    },
    bindings : { 
        ".student-id": "student_id",
        ".last-name": "last_name",          
        ".first-name": "first_name",
        ".status": "status",
        ".comment": "comment",
        ".status": "status",
        ".recitation": "recitation",
        ".email": {observe: "email_address",events: ["blur"]},
        ".user-id": {observe: "user_id",events: ["blur"]},
        ".password": "password",
        ".permission": { 
            observe: "permission",
            selectOptions: { collection: function() { return config.permissions;}}
        }
    },

    saveAndClose: function(){ 
        var save = this.saveAndAddStudent();
        if(save){
            this.users.add(this.collection.models);
            this.collection.reset();
            this.close();               
        }
    },
    saveAndAddStudent: function (){ 
        var userExists = this.model.userExists(this.users);
        if(userExists){
            this.$(".message-pane").addClass("alert-danger").html(this.messageTemplate({type:"user_already_exists",
                opts: {user_id: this.model.get("user_id")}}));
            return false;
        }
        if(this.model.isValid(true)){
            this.collection.add(new User(this.model.attributes));
            this.$(".message-pane").addClass("alert-info").html(this.messageTemplate({type: "man_user_added",
                            opts: {users: this.collection.pluck("user_id")}}));
            
            this.model.set(this.model.defaults);
            return true;
        }
        return false;
    }
});

var AddStudentFileView = ModalView.extend({
        initialize: function(options){
            _.bindAll(this, 'render','importStudents','validateColumn'); // every function that uses 'this' as the current object should be in here
            _(this).extend(_(options).pick("users","messageTemplate"));
            this.collection = new UserList();
            this.model = new User();
            this.model.collection = this.collection; // helps with the validation. 
            Backbone.Validation.bind(this);

            _(options).extend({
                modal_size: "modal-lg",
                modal_header: "Add Users from a File",
                modal_body: $("#add_student_file_dialog_content").html(),
                modal_buttons: $("#import-file-buttons").html()
            })
            //this.setValidation();
            ModalView.prototype.initialize.apply(this,[options]);
        },
        childEvents: {
            "click .import-students-button": "importStudents",
            "change input#files": "readFile",
            "change input#useLST" : "setHeadersForLST",
            "change input#useFirst" : "useFirstRow",
            "click  .reload-file": "loadFile",
            "change select.colHeader": "validateColumn",
            "change #selectAllASW":  "selectAll",
            "click  .close-button": "closeErrorPane",
            "click  .cancel-button": "close",
            "click  .import-help-button": "showImportHelp",
            "click  .help-pane button": "closeHelpPane"
        },
        closeHelpPane: function () {
            this.$(".help-pane").hide("slow");
        },
        closeErrorPane: function () {
            this.$(".error-pane").hide("slow");
        },
        showError: function(errorMessage){
            this.$(".error-pane").show("slow");
            this.$(".error-pane-text").text(errorMessage);
        },
        showImportHelp: function () {
            this.$(".help-pane").removeClass("hidden").show("slow");
        },
        render: function(){
            ModalView.prototype.render.apply(this);
            return this; 
        },
        readFile: function(evt){
            var self = this; 
            $("li#step1").css("display","none");  // Hide the first step of the Wizard
            $("li#step2").css("display","block");  // And show the next step.
            $("button#importStudFromFileButton").css("display","block");
            
            this.loadFile();
        },
        
        loadFile: function (event) {
            var self = this;
            this.file = $("#files").get(0).files[0];
            $('#list').html('<em>' + escape(this.file.name) + '</em>');
        
            // Need to test if the browser can handle this new object.  If not, find alternative route.
        

            if (!(this.file.name.match(/\.(lst|csv)$/))){
                this.showError(this.messageTemplate({type: "csv_file_needed"}));
                return;
            }
            this.reader = new FileReader();

            this.reader.readAsText(this.file);
            this.reader.onload = function (evt) {           
                var content = evt.target.result
                    , headers = _(config.userProps).pluck("longName");
                headers.splice(0,0,"");
                // Parse the CSV file
                
                //var str = util.CSVToHTMLTable(content,headers);
                var arr = util.CSVToHTMLTable(content,headers);

                $("#studentTable").html(_.template($("#imported-from-file-table").html(),{array: arr, headers: headers}))

                // build the table and set it up to scroll nicely.      
                //$("#studentTable").html(str);
                $("div.inner").width(25+($("#studentTable table thead td").length)*125);
                $("#inner-table td").width($("#studentTable table thead td:nth-child(2)").width()+4)
                $("#inner-table td:nth-child(1)").width($("#studentTable table thead td:nth-child(1)").width())

                // test if it is a classlist file and then set the headers appropriately
                
                var re=new RegExp("\.lst$","i");
                if (re.test(self.file.name)){self.setHeadersForLST();}

                self.$(".import-students-button").removeClass("disabled");
                self.$(".reload-file").removeClass("disabled");
                self.delegateEvents();
            }
        },
        selectAll: function () {
            this.$(".selRow").prop("checked",this.$("#selectAllASW").is(":checked"));
        },
        importStudents: function () {  // PLS:  Still need to check if student import is sucessful, like making sure that user_id is valid (not repeating, ...)
            // First check to make sure that the headers are not repeated.
            var self = this;
            var tmp = $("select.colHeader").map(function(i,v){return {header: $(v).val(), position: i};});
            var headers = _(tmp).filter(function(h) { return h.header!=="";})
            _(headers).each(function(h){ h.shortName = _(config.userProps).findWhere({longName: h.header}).shortName;});
            

            // check that the heads are unique

            var sortedHeads = _(_(headers).pluck("header")).sortBy();
            var uniqueHeads = _.uniq(sortedHeads,true);

            if(! _.isEqual(sortedHeads,uniqueHeads)){

                this.$(".error-pane-text").html("Each Column must have a unique Header.")
                this.$(".error-pane").show("slow");
                return false;
            }

            // check that "First Name", "Last Name" and "Login name" are among the chosen headers.

            var requiredHeaders = ["First Name","Last Name", "Login Name"];
            var containedHeaders = _(sortedHeads).intersection(requiredHeaders).sort();
            if (! _.isEqual(requiredHeaders,containedHeaders)) {
                this.$(".error-pane-text").html("There must be the following fields imported: " + requiredHeaders.join(", "))
                this.$(".error-pane").show("slow");
                return;
            }
            

            // Determine the rows that have been selected.
            
            var rows = _.map($("input.selRow:checked"),function(val,i) {return parseInt(val.id.split("row")[1]);});
            _(rows).each(function(row){
                var props = {};
                _(headers).each(function(obj){
                    props[obj.shortName] = $.trim($("tr#row"+row+" td.column" + obj.position).html());
                });
                var user = new User(props);
                user.id = void 0;  // make sure that the new users will be added with a POST instead of a PUT
                self.users.add(user);
            
            });
            this.close();
        },
        useFirstRow: function (){
            var self = this;        
            // If the useFirstRow checkbox is selected, try to match the first row to the headers. 
            
            if ($("input#useFirst").is(":checked")) {
                _(config.userProps).each(function(user,j){
                var re = new RegExp(user.regexp,"i");
                
                $("#sTable thead td").each(function (i,head){
                    if (re.test($("#inner-table tr:nth-child(1) td:nth-child(" + (i+1) + ")").html())) {
                        $(".colHeader",head).val(user.longName);
                        self.validateColumn(user.longName);  // keep track of the location of the Login Name
                    }
                });
                });
            } else {  // set the headers to blank. 
                $("#sTable thead td").each(function (i,head){ $(".colheader",head).val("");});
                $("#inner-table tr").css("background-color","none");
            }
        },
        validateColumn: function(arg) {  
            var headerName = _.isString(arg) ? arg : $(arg.target).val()
                , self = this
                , headers = this.$(".colHeader").map(function (i,col) { return $(col).val();})
                , loginCol = _(headers).indexOf("Login Name")
                , changedProperty = _(config.userProps).findWhere({longName: headerName}).shortName
                , colNumber = _(this.$(".colHeader option:selected").map(function(i,v) { return $(v).val()})).indexOf(headerName);
            

            // Detect where the Login Name column is in the table and show duplicate entries of users.           
            if (loginCol < 0 ) { 
                $("#inner-table tr#row").css("background","white");  // if Login Name is not a header turn off the color of the rows
            } else {
                var impUsers = $(".column" + loginCol).map(function (i,cell) { 
                            return $.trim($(cell).html());});  
            
                var userIDs = this.users.pluck("user_id");
                var duplicateUsers = _.intersection(impUsers,userIDs);
            
                // highlight where the duplicates users are and notify that there are duplicates.  

                $(".column" + loginCol).each(function (i,cell) {    
                   if (_(duplicateUsers).any(function (user) { 
                        return user.toLowerCase() == $.trim($(cell).html()).toLowerCase();}
                        )){
                        $("#inner-table tr#row" + i).css("background-color","rgba(255,128,0,0.5)"); 
                    }
                });

            }
             
             // Validate the user property in the changed Header
             
                 
            $("tbody td.column" + colNumber).each(function(i,cell){
                var value = $(cell).html().trim(),
                    errorMessage = self.model.preValidate(changedProperty,value);
                if ((errorMessage !== "") && (errorMessage !== false)) {
                    self.$(".error-pane-text").html("Error for the " + headerName + " with value " +  value + ":  " + errorMessage)
                    self.$(".error-pane").show("slow");
                    $(cell).css("background-color","rgba(255,0,0,0.5)");
                }
            });
             
        },
        setHeadersForLST: function(){
            var self = this;
            _(config.userProps).each(function (prop,i) {
                var col = $("select#col"+i);
                col.val(prop.longName);
                self.validateColumn(prop.longName);
            });
        }
    });
   

return ClasslistView;
    
});


