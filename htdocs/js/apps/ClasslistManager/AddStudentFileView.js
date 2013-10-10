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
	    
		initialize: function(){
		    _.bindAll(this, 'render','importStudents','openDialog','closeDialog','validateColumn'); // every function that uses 'this' as the current object should be in here
		    this.collection = new UserList();
		    this.model = new User();
		    Backbone.Validation.bind(this);
		    this.users = this.options.users;
		    this.render();
		    
		    this.$el.dialog({autoOpen: false, modal: true, title: "Add Students from a File",
							width: (0.95*window.innerWidth), height: (0.85*window.innerHeight) });
		},
		events: {
		    "click button#importStudFromFileButton": "importStudents",
		    "change input#files": "readFile",
		    "change input#useLST" : "setHeadersForLST",
		    "change input#useFirst" : "useFirstRow",
		    "click .reload-file": "loadFile",
		    "change select.colHeader": "validateColumn",
		    "change #selectAllASW":  "selectAll"
		},
		openDialog: function () { this.$el.dialog("open");},
		closeDialog: function () {this.$el.dialog("close");},
		render: function(){
		    var self = this;
		    //this.errorPane = new Closeable({id: "error-bar"});
		    this.errorPane.$el.addClass("alert-error");
		    this.$el.html(this.errorPane.el);
		    $("button.close",this.errorPane.el).click(function () {self.errorPane.close();}); // for some reason the event inside this.error is not working  this is a hack.
		   
		    this.$el.append($("#add_student_file_dialog_content").html());
		    
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

				self.delegateEvents();
			}
		},
		selectAll: function () {
			$(".selRow").attr("checked",$("#selectAllASW").is(":checked"));
		},
		importStudents: function () {  // PLS:  Still need to check if student import is sucessful, like making sure that user_id is valid (not repeating, ...)
		    // First check to make sure that the headers are not repeated.
		    var self = this;
		    var headers = [];
		    _($("select[class='colHeader']")).each(function(obj,j){if ($(obj).val() != "") headers.push({header: $(obj).val(), position: j});});
		    
		    var heads = _(headers).map(function (obj) {return obj.header;});
		    var sortedHeads = _(heads).sortBy(function (str) {return str;});
		    
		    // Determine if the user has selected a unique set of headers.  
		    
		    var validHeaders=true;
		    for (var i=0;i<sortedHeads.length-1;i++){if(sortedHeads[i]==sortedHeads[i+1]) {validHeaders=false; break;}};
		    if (!validHeaders) {alert("Each Column must have a unique Header.");  return false;}
		    



		    // This is an array of the column numbers that the headers are in.  
		    
		    var headCols = _.map(headers, function (value,j)
					 { return _.find(_.map($("select.colHeader"),
							       function (val,i) {if (val.value==value) return i; else return -1;}),
							 function (num) { return typeof num === 'number' && num % 1 == 0; })});
		    

		    var requiredHeaders = ["First Name","Last Name", "Login Name"];
		    var containedHeaders = _(sortedHeads).intersection(requiredHeaders);
		    if (!((containedHeaders.length === requiredHeaders.length) &&
		    	(_(containedHeaders).difference(requiredHeaders).length === 0))) {
		    	self.errorPane.addMessage({text: "There must be the following fields imported: " + requiredHeaders.join(", ")});
			    return;
		    }

		    // Determine the rows that have been selected.
		    
		    var rows = _.map($("input.selRow:checked"),function(val,i) {return parseInt(val.id.split("row")[1]);});
		    _.each(rows, function(row){
			var user = new User();
			_.each(headers, function(obj){
				for(var i = 0; i < config.userProps.length; i++)
				{
				    // set the appropriate user property given the element in the table. 
				   if(obj.header==config.userProps[i].longName) {
				    var props = '{"' +  config.userProps[i].shortName + '":"' +$.trim($("tr#row"+row+" td.column" + obj.position).html()) + '"}';
				    user.set($.parseJSON(props));  
				}
			    }});
			
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
			 	, changedProperty = _(config.userProps).where({longName: headerName}).shortName
			 	, colNumber = _(this.$(".colHeader option:selected").map(function(i,v) { return $(v).val()})).indexOf(headerName);
			

			// Detect where the Login Name column is in the table and show duplicate entries of users.  		 
		    if (loginCol < 0 ) { 
		    	$("#inner-table tr#row").css("background","white");  // if Login Name is not a header turn off the color of the rows
		    } else {
				var impUsers = $(".column" + loginCol).map(function (i,cell) { 
							return $.trim($(cell).html()).toLowerCase();});  // determine the proposed login names in lower case   
			
				var users = this.users.map(function (user) {return user.get("user_id").toLowerCase();});
				var duplicateUsers = _.intersection(impUsers,users);
			
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
		     
			     
		    $(".column" + colNumber).each(function(i,cell){
			    if (i>0){ // skip the header row
				var value = $(cell).html().trim(),
				    errorMessage = self.model.preValidate(changedProperty,value);
				if ((errorMessage !== "") && (errorMessage !== false)) {
				    self.errorPane.addMessage({ text: "Error for the " + changedHeader + " with value " +  value + ":  " + errorMessage + "<br/>"});
				    $(cell).css("background-color","rgba(255,0,0,0.5)");
				
				}
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