//  This is the main view for the Student Progress Page.

define(['backbone', 'underscore','views/MainView','config','views/CollectionTableView','models/UserSetList'], 
function(Backbone, _,MainView,config,CollectionTableView,UserSetList){
var StudentProgressView = MainView.extend({
	initialize: function (options){
		var self = this;
		_(this).bindAll("buildTable","render","changeDisplay");
		MainView.prototype.initialize.call(this,options);
		this.tableSetup();
		this.state.on({
			"change:type": this.changeDisplay, 
			"change:set_id change:user_id": this.buildTable,
		})

	},
	render: function (){
		var self = this;
		this.$el.html($("#student-progress-template").html());
		this.stickit(this.state,this.bindings);
		if(this.collection){
			this.changeDisplay();
			this.progressTable = new CollectionTableView({columnInfo: this.cols, collection: this.collection, 
	                    paginator: {page_size: 10, button_class: "btn btn-default", row_class: "btn-group"}}).render();
			this.progressTable.on("page-changed",function(num){
	        			self.state.set({page_num: num});
	        			self.showHideColumns();
	        		}).gotoPage(this.state.get("page_num")).$el.addClass("table table-bordered table-condensed")
			this.$el.append(this.progressTable.el);
	
	        // set up some styling
	        this.progressTable.$(".paginator-row td").css("text-align","center");
	        this.progressTable.$(".paginator-page").addClass("btn");
	        this.showHideColumns();
		} else {
			this.buildTable();
		}
		MainView.prototype.render.apply(this);
	    return this;
	},
	bindings: {
		".progress-type": {observe: "type", selectOptions: {collection: ["sets","users"]}},
		".progress-student-select": {observe: "user_id", selectOptions: { 
			collection: function () {
				return this.users.pluck("user_id");
			}, 
			defaultOption: {value: null, label: "Select User..."}}},
		".progress-set-select": {observe: "set_id", selectOptions: { 
			collection: function () {
				return this.problemSets.pluck("set_id");
			}, 
			defaultOption: {value: null, label: "Select Set..."}}}
	},
	getDefaultState: function () {
		return {set_id: "", user_id: "", type: "users", page_num: 0};
	},
	changeDisplay: function(){
		this.$(".collection-table").remove();
		switch(this.state.get("type")){
			case "sets":
				this.$(".progress-student-select").addClass("hidden");
				this.$(".progress-set-select").removeClass("hidden");
				this.state.set({user_id: ""});
				break;
			case "users":
				this.$(".progress-set-select").addClass("hidden");
				this.$(".progress-student-select").removeClass("hidden");
				this.state.set({set_id: ""});
				break;
		}
	},
	showHideColumns: function () {
		this.$(".login-name,.set-id").removeClass("hidden");
        switch(this.state.get("type")){
			case "users":
				this.$(".login-name").addClass("hidden");
				break;
			case "sets":
				this.$(".set-id").addClass("hidden");
				break;
		}
	},
	buildTable: function () {
		var self = this;
		if (this.state.get("type")==="users"){
			var _user = this.users.findWhere({user_id: this.state.get("user_id")});
			if(! _user){ 
				this.collection = new UserSetList([],{type: "sets"});
				this.render();
			} else {
				(this.collection = new UserSetList([],{user: _user.get("user_id"), type: "sets", loadProblems: true}))
				.fetch({success: function(data){self.render();}});	
			}
		} else if (this.state.get("type")==="sets"){
			var _set = this.problemSets.findWhere({set_id: this.state.get("set_id")});
			if(! _set){ 
				this.collection = new UserSetList([],{type: "users"});
				this.render();
			} else {
				(this.collection = new UserSetList([],{problemSet: _set, type: "users",loadProblems: true}))
					.fetch({success: function (data){self.render();}});	
			}
		}
	},
	getHelpTemplate: function () {

	},
	tableSetup: function () {
        var self = this;
        this.cols = [
            {name: "Login Name", key: "user_id", classname: "login-name", datatype: "string"},
            {name: "Set Name", key: "set_id", classname: "set-id", datatype:"string"},
            {name: "Score", key: "score", classname: "score", datatype: "integer", stickit_options: {
            	update: function($el, val, model, options) {
            		if(model.get("problems").size()===0){
            			$el.html("");
            			return;
            		}
        		 	var status = _(model.get("problems").pluck("status")
        		 			.map(function(s) { return s===""?0:parseFloat(s);})).reduce(function(p,q) {return p+q;});
					var total = _(model.get("problems").pluck("value")).reduce(function(p,q) { return parseFloat(p)+parseFloat(q);}); 
            		$el.html(config.displayFloat(status,2) + "/" + total);
            	}
            }},
            {name: "Problems", key: "problems", classname: "problems", datatype: "string", stickit_options: {
            	update: function($el, val, model, options) {
            		if(model.get("problems").size()===0){
            			$el.html("");
            			return;
            		}
            		$el.html(model.get("problems").map(function(p){
            			var status = p.get("status")===""? 0: parseFloat(p.get("status"));
            			if(p.get("attempted")=="0" || p.get("attempted")==="") { return "  .";}
            			else if(p.get("status")==p.get("value")){ return "  C";}
            			else {
            				return " "+(parseInt(100*status/parseFloat(p.get("value"))));
            			}
            		}).join(""));
            	}
            }},
        ];
    }

});

return StudentProgressView;
});
