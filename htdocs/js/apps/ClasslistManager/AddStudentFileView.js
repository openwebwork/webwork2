    // This is the View for the dialog for addings students manually    

define(['Backbone', 
	'underscore',
	'models/User',
	'models/UserList',
	//'file-saver', 
	'config',
	'../../lib/util'], function(Backbone, _,User,UserList,config,util){	
	    var AddStudentFileView = Backbone.View.extend({
		tagName: "div",
		id: "addStudFileDialog",
	    
		initialize: function(options){
		    _.bindAll(this, 'render','importStudents','openDialog','closeDialog','validateColumn'); // every function that uses 'this' as the current object should be in here
		    this.collection = new UserList();
		    this.model = new User();
		    Backbone.Validation.bind(this);
		    this.users = options.users;
		    this.render();
		    
		    this.$el.dialog({autoOpen: false, modal: true, title: "Add Students from a File",
							width: (0.95*window.innerWidth), height: (0.85*window.innerHeight) });
		},
		events: {
		    "click button#importStudFromFileButton": "importStudents",
		    "change input#files": "readFile",
		    "change input#useLST" : "setHeadersForLST",
		    "change input#useFirst" : "useFirstRow",
		    "click  .reload-file": "loadFile",
		    "change select.colHeader": "validateColumn",
		    "change #selectAllASW":  "selectAll",
		    "click	.close-button": "closeErrorPane",
		    "click  .cancel-button": "closeDialog",
		    "click  .import-help-button": "showImportHelp",
		    "click  .help-pane button": "closeHelpPane"
		},
		closeHelpPane: function () {
			this.$(".help-pane").hide("slow");
		},
		closeErrorPane: function () {
			this.$(".error-pane").hide("slow");
		},
		showImportHelp: function () {
			this.$(".help-pane").show("slow");
		},
		openDialog: function () { this.$el.dialog("open");},
		closeDialog: function () {this.$el.dialog("close");},
		render: function(){
		    var self = this;
		    this.$el.html($("#add_student_file_dialog_content").html());
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
		

		    if (!(this.file.type.match(/csv/))){
		    	this.errorPane.setMessage({text: "You must upload a csv file"});
		    	return;
		    }
		    this.reader = new FileReader();

		    this.reader.readAsText(this.file);
		    this.reader.onload = function (evt) {			
				var content = evt.target.result
					, headers = _(config.userProps).pluck("longName");
				headers.splice(0,0,"");
				// Parse the CSV file
				
				var str = util.CSVToHTMLTable(content,headers);

				// build the table and set it up to scroll nicely. 		
				$("#studentTable").html(str);
				$("div.inner").width(25+($("#sTable thead td").length)*175);
				$("#inner-table td").width($("#sTable thead td:nth-child(2)").width()+4)
				$("#inner-table td:nth-child(1)").width($("#sTable thead td:nth-child(1)").width())

				// test if it is a classlist file and then set the headers appropriately
				
				var re=new RegExp("\.lst$","i");
				if (re.test(self.file.name)){self.setHeadersForLST();}

				$("#importStudFromFileButton").removeClass("disabled");
				self.$(".reload-file").removeClass("disabled");
				self.delegateEvents();
			}
		},
		selectAll: function () {
			$(".selRow").attr("checked",$("#selectAllASW").is(":checked"));
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
		    

		this.closeDialog();
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
		    self.errorPane.clear();

		    _(config.userProps).each(function (prop,i) {
			var col = $("select#col"+i);
			col.val(prop.longName);
			self.updateHeaders(col); });
		    }
	});
		/* appendRow: function(user){
		    var tableRow = new UserRowView({model: user});
		    $("table#man_student_table tbody",this.el).append(tableRow.el);
		}, */

    
    return AddStudentFileView;

});