define(['backbone', 'underscore','views/MainView', 'apps/util','models/ProblemSetList','models/ProblemSet','config','bootstrap'], 
	function(Backbone, _,MainView, util,ProblemSetList,ProblemSet,config){

var ImportExportView = MainView.extend({
    initialize: function (options){
    	MainView.prototype.initialize.call(this,options);
    	var self = this;
        _.bindAll(this,"render");
        this.problemSets = options.problemSets;
        this.problemSetsToImport = new ProblemSetList();
        this.rowViews=[];
        this.problemSetsToImport.on("change:name",function (_set) {
    		self.checkSetNames();
    		_set.id=_set.get("set_id");
    	});
    },
    render: function () {
        this.$el.html($("#import-export-template").html());
        this.$(".date-shift-input").datepicker();
        return this;
    },
    renderSets: function () {
    	self = this;
        this.$(".import-table").removeClass("hidden");
        var table = this.$(".import-table table tbody").empty();
        this.problemSetsToImport.each(function(_set,i){
        	self.rowViews[i] = (new ProblemSetRowView({model: _set,problemSets: self.problemSets})).render(); 
            table.append(self.rowViews[i].el);
        });
        this.checkSetNames();
        return this;
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
	checkSetNames: function () {
		var self = this
			, valid =[];
		this.problemSetsToImport.each(function(_set,i){
			valid[i]=self.rowViews[i].setNameValid();
		});
        if(_.every(valid)){
        	this.$(".import-error").addClass("hidden");
        } else {
        	this.$(".import-error").removeClass("hidden");
        	this.$(".import-error").text("The set names in red below already exist. It will not be imported unless" +
        			" the name is changed.");
        }

	},
	shiftDates: function () {
		var shiftDate = moment(this.$(".date-shift-input").val(),"MM/DD/YYYY");
		var sets = this.getSelectedSets();
		if(sets.length>0 && shiftDate){
			var shift = this.getDateShift(moment.unix(sets[0].get("open_date")));
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
	getDateShift: function(firstDate){
		
		if(typeof(firstDate)=="undefined"){
			return 0;
		}

		// shift all of the dates if selected.
		if(this.$(".date-shift-checkbox").prop("checked")){
			var shiftDate = moment(this.$(".date-shift-input").val(),"MM/DD/YYYY");
			shiftDate.hour(firstDate.hour());
			shiftDate.minute(firstDate.minute());
			return shiftDate.diff(firstDate,"days");
		} else {
			return 0;
		}		
	},
	importSets: function () {
		var self = this;
		var sets = this.getSelectedSets();

		// shift all of the dates if selected.
		if(sets.length>0){
			var shift = this.getDateShift(moment.unix(sets[0].get("open_date")));
			_(sets).each(function(_set){
				_set.set({open_date: moment.unix(_set.get("open_date")).add(shift,"days").unix(),
					due_date: moment.unix(_set.get("due_date")).add(shift,"days").unix(),
					answer_date: moment.unix(_set.get("answer_date")).add(shift,"days").unix(),
					assigned_users: [config.courseSettings.user]});
				if(! self.problemSets.findWhere({name: _set.get("set_id")})){
					delete _set.id; // ensures that backbone sends a post request.
					self.problemSets.add(_set);
					var view = _(self.rowViews).find(function(view){ return view.model.get("set_id")===_set.get("set_id");});
					view.remove();
				}

			});
		}
	},
    loadSetDefinition: function(evt){
        var self = this;
        //this.problemSetsToImport = new ProblemSetList();
        var files = evt.target.files;
       	_(files).each(function(file){
	        var reader = new FileReader();

	        // Closure to capture the file information.
	        reader.onload = (function(blob) {
	            var setName = /^set(.*).def$/.exec(file.name)
	            	, attrs = util.readSetDefinitionFile(blob.target.result)
	            	, probSet = new ProblemSet(_.extend(attrs,{set_id: setName[1]}));
	            

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
    initialize: function(options){
    	this.problemSets = options.problemSets;
    },
    render: function(){
        this.$el.html($("#import-problem-set-row-template").html());
        this.stickit();
        return this;
    },
    bindings: {
        ".set-name": "set_id",
        ".num-probs": {observe: "problems", onGet: function(val) { return val.length;}},
        ".open-date": "open_date",
        ".due-date": "due_date",
        ".answer-date": "answer_date",
    },
    setNameValid: function () {
    	if(this.problemSets.findWhere({name: this.model.get("set_id")})){
    		this.$(".set-name").addClass("alert alert-danger");
    		return false;
    	} else {
    		this.$(".set-name").removeClass("alert alert-danger");
    		return true;
    	}
    }
 });

return ImportExportView;

});
