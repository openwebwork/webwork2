    // This is the View for the dialog for addings students manually    

define(['Backbone', 
	'underscore',
	'Closeable',
	'../../lib/models/User',
	'../../vendor/other/FileSaver', 
	'../../vendor/other/BlobBuilder',
	'config',
	'../../lib/util'], function(Backbone, _,Closeable,User,saveAs,BlobBuilder,config,util){	
	    var AddStudentFileView = Backbone.View.extend({
		tagName: "div",
		id: "addStudFileDialog",
	    
		initialize: function(){
		    _.bindAll(this, 'render','importStudents','addStudent','appendRow'); // every function that uses 'this' as the current object should be in here
		    this.collection = new TempUserList();
		    this.model = new User();
		    Backbone.Validation.bind(this);
		    this.parent = this.options.parent;
		    this.render();
		    
		    //for(var i = 0; i<1; i++) {this.collection.add(new webwork.User())}  // add a single blank line. 
		    
		    this.$el.dialog({autoOpen: false, modal: true, title: "Add Students from a File",
							width: (0.95*window.innerWidth), height: (0.95*window.innerHeight) });
		},
		events: {
		    "click button#importStudFromFileButton": "importStudents",
		    "change input#files": "readFile",
		    "change input#useLST" : "setHeadersForLST",
		    "change input#useFirst" : "useFirstRow"
		},
		openDialog: function () { this.$el.dialog("open");},
		closeDialog: function () {this.$el.dialog("close");},
		render: function(){
		    var self = this;
		    this.errorPane = new Closeable({id: "error-bar"});
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
			
		    this.file = $("#files").get(0).files[0];
		    $('#list').html('<em>' + escape(this.file.name) + '</em>');
	    
		    
	        
		    // Need to test if the browser can handle this new object.  If not, find alternative route.
		
		var sizeInBytes = 1024 * 1024,
		    prefix = 'filetest';

	/*	FSFactory(sizeInBytes, 'test_fs', function(err, fs) {
		    fs.readFile(this.file, function(err, data){
			 console.log(data);
		    });
		}); */
		
		    var reader = new FileReader();
	        
		    reader.onload = function(event) {
			var content = event.target.result;
			headers = _(config.userProps).map(function(prop) {return prop.longName;});
			headers.splice(0,0,"");
			// Parse the CSV file
			
			var str = util.CSVToHTMLTable(content,headers);

			// build the table and set it up to scroll nicely. 		
			$("#studentTable").html(str);
			$("#selectAllASW").click(function(){ $(".selRow").attr("checked",$("#selectAllASW").is(":checked")); });
			$("div.inner").width(25+($("#sTable thead td").length)*175);
			$("#inner-table td").width($("#sTable thead td:nth-child(2)").width()+4)
			$("#inner-table td:nth-child(1)").width($("#sTable thead td:nth-child(1)").width())

			// test if it is a classlist file and then set the headers appropriately
			
			var re=new RegExp("\.lst$","i");
			if (re.test(self.file.name)){self.setHeadersForLST();}

		        $("select.colHeader").change(function(evt) {self.updateHeaders(evt.target);})
		    } 
			    
		    reader.readAsText(this.file);
		
			
		},
		importStudents: function () {  // PLS:  Still need to check if student import is sucessful, like making sure that user_id is valid (not repeating, ...)
		    // First check to make sure that the headers are not repeated.
		    var self = this;
		    var headers = [];
		    _($("select[class='colHeader']")).each(function(obj,j){if ($(obj).val() != "") headers.push({header: $(obj).val(), position: j});});
		    
		    //console.log(headers);
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
				    user.set($.parseJSON(props),{silent:true});  // send silent: true so this doesn't fire an "change" event resulting in a server hit
				}
			    }});
			
			self.parent.collection.add(user);
			
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
			    self.updateHeaders($(".colHeader",head));  // keep track of the location of the Login Name
			    }
			});
		    });
		    } else {  // set the headers to blank. 
			$("#sTable thead td").each(function (i,head){ $(".colheader",head).val("");});
			$("#inner-table tr").css("background-color","none");
		    }
		},
		updateHeaders: function(target) {  // Detect where the Login Name column is in the table and show duplicate entries of users. 
		    var self = this,
			 changedHeader = $(target).val(),
			 headers = _($(".colHeader")).map(function (col) { return $(col).val();}),
			 loginCol = _(headers).indexOf("Login Name"),
			 changedProperty = (_(config.userProps).find(function(user) {return user.longName===changedHeader})).shortName,
			 colNumber = parseInt($(target).attr("id").split("col")[1]);
			 		 
		     if (loginCol < 0 ) { $("#inner-table tr#row").css("background","white")} // if Login Name is not a header turn off the color of the rows
		     else {
			var impUsers = $(".column" + loginCol).map(function (i,cell) { return $.trim($(cell).html()).toLowerCase();}); 
			
			var users = self.parent.collection.map(function (user) {return user.attributes.user_id.toLowerCase();});
			var duplicateUsers = _.intersection(impUsers,users);
			
			$(".column" + loginCol).each(function (i,cell) {
			   if (_(duplicateUsers).any(function (user) { return user.toLowerCase() == $.trim($(cell).html()).toLowerCase();})){
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
				    self.errorPane.appendHTML("Error for the " + changedHeader + " with value " +  value + ":  " + errorMessage + "<br/>");
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
		    },
		appendRow: function(user){
		    var tableRow = new UserRowView({model: user});
		    $("table#man_student_table tbody",this.el).append(tableRow.el);
		},
		addStudent: function (){ this.collection.add(new User);}
	    });

    // This is a Backbone collection of webwork.User(s).  This is different than the webwork.userList class  because we don't need
    // the added expense of additions to the server.
    
    var TempUserList = Backbone.Collection.extend({model:User});
    

    return AddStudentFileView;

});