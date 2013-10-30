define(['Backbone', 'underscore', '../../lib/util','models/ProblemSetList','models/ProblemSet','config','bootstrap'], 
	function(Backbone, _, util,ProblemSetList,ProblemSet,config){

var ImportExportView = Backbone.View.extend({
    headerInfo: {template: "#importExport-header"},
    initialize: function (){
        _.bindAll(this,"render");
        this.problemSetsToImport = new ProblemSetList();
        this.problemSetsToImport.on("add",function(set){
        	console.log("adding " + set.get("set_id"));
        })
    },
    render: function () {
        this.$el.html($("#import-export-template").html());
        this.$(".date-shift-input").datepicker();
    },
    renderSets: function () {
    	self = this;
        this.$(".import-table").removeClass("hidden");
        var table = this.$(".import-table table tbody").empty();
        this.problemSetsToImport.each(function(_set){
        	var rowView = (new ProblemSetRowView({model: _set,problemSets: self.options.problemSets})).render(); 
            table.append(rowView.el);
            rowView.checkSetName();
        });
    },
    events: {"change #import-from-file": "loadSetDefinition",
			"change .date-shift-checkbox": "toggleDateShift",
			"change .select-all-checkbox": "selectAll",
			"change .date-shift-input": "shiftDates",
			"click .import-button": "importSets"},
	toggleDateShift: function () {
		this.$(".date-shift-container").toggleClass("hidden");
		if(! this.$(".date-shift-container").hasClass("hidden")){
			this.$(".date-shift-input").focus();
			this.shiftDates();
		}
	},
	shiftDates: function () {
		var theDate = moment(this.$(".date-shift-input").val(),"MM/DD/YYYY");
		var sets = this.getSelectedSets();
		if(sets.length>0 && theDate){
			var shift = theDate.diff(moment.unix(sets[0].get("open_date")),"days");
			this.$(".import-message").text("The dates of the selected sets will be shifted by " + shift + " days.");
		}
	},
	selectAll: function (){
		this.$(".import-checkbox").prop("checked",this.$(".select-all-checkbox").prop("checked"));
	},
	getSelectedSets: function() {
	 	var setNames = this.$(".import-checkbox:checked").map(function(i,v){ 
	 			return $(v).closest("tr").find(".set-name").text();}).toArray();
		return this.problemSetsToImport.filter(function(_set) {return _(setNames).contains(_set.get("set_id"));});
	},
	importSets: function () {
		var sets = this.getSelectedSets();
		console.log(sets);
	},
    loadSetDefinition: function(evt){
        var self = this;
        //this.problemSetsToImport = new ProblemSetList();
        var files = evt.target.files;
       	_(files).each(function(file){
	        var reader = new FileReader();

	        // Closure to capture the file information.
	        reader.onload = (function(blob) {
	            var probSet = new ProblemSet()
	            	, setName = /^set(.*).def$/.exec(file.name)
	            	, attrs = util.readSetDefinitionFile(blob.target.result);
	            _.extend(attrs,{set_id: setName[1]});
	            probSet.parse(attrs);

	            // convert the webwork date-time to unix epoch
	            var params = _.extend(probSet.pick("open_date","due_date","answer_date"),
	            					{timeZone: config.settings.getSettingValue("siteDefaults{timezone}")});
	            $.post(config.urlPrefix + "utils/dates",params,function(data){
	            	probSet.set(data);
		        });

	            self.problemSetsToImport.add(probSet);
	            self.renderSets();
	        });

	        reader.readAsText(file);
	    });
    }

});

var ProblemSetRowView = Backbone.View.extend({
    tagName: "tr",
    initialize: function () {
    	var self = this;
    	this.model.on("change:set_id",function () {
    		self.checkSetName();
    	})
    },
    render: function(){
        this.$el.html($("#import-problem-set-row-template").html());
        this.stickit();
        return this;
    },
    bindings: {
        ".set-name": "set_id",
        ".open-date": "open_date",
        ".due-date": "due_date",
        ".answer-date": "answer_date",
    },
    checkSetName: function () {
    	if(self.options.problemSets.findWhere({set_id: this.model.get("set_id")})){
    		this.$(".set-name").addClass("alert alert-error")
	    			.popover({content: "This set name already exists."
	    				,placement: "left"}).popover("show");
    	} else {
    		this.$(".set-name").removeClass("alert alert-error");
    		this.$(".set-name").popover("hide");
    	}
    }
 });

return ImportExportView;

});
