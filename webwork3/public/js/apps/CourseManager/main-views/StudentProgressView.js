//  This is the main view for the Student Progress Page.

define(['backbone', 'underscore','views/MainView','config','views/CollectionTableView','models/UserSetList'], 
function(Backbone, _,MainView,config,CollectionTableView,UserSetList){
var StudentProgressView = MainView.extend({
	initialize: function (options){
		var self = this;
		MainView.prototype.initialize.call(this,options);
		_(this).bindAll("selectSet","changeDisplay","selectUser");
		this.tableSetup();
		this.model = new Backbone.Model({set_id: "", user_id: "", type: "users"});
		this.model.on({
			"change:type": this.changeDisplay,
			"change:set_id": this.selectSet,
			"change:user_id": this.selectUser,
			"change": function(){
				self.eventDispatcher.trigger("save-state");
			}
		})

	},
	render: function (){
		this.$el.html($("#student-progress-template").html());
		this.stickit();
		if(this.collection){
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
    getState: function () {
        return this.model.attributes;
    },
    setState: function(_state){
    	if(_state){
    		this.model.set(_state);
    	}
    	return this;
    },
	changeDisplay: function(){
		this.$(".collection-table").remove();
		switch(this.model.get("type")){
			case "sets":
				this.$(".progress-student-select").addClass("hidden");
				this.$(".progress-set-select").removeClass("hidden");
				break;
			case "users":
				this.$(".progress-set-select").addClass("hidden");
				this.$(".progress-student-select").removeClass("hidden");
				break;
		}
	},
	selectSet: function (){
		var self = this;
		var _set = this.problemSets.findWhere({set_id: this.model.get("set_id")});
		(this.collection = new UserSetList([],{problemSet: _set, type: "users",loadProblems: true}))
						.fetch({success: function (data){self.buildTable();}});
	},
	selectUser: function (){
		var self = this;
		var _user = this.users.findWhere({user_id: this.model.get("user_id")});
		(this.collection = new UserSetList([],{user: _user.get("user_id"), type: "sets", loadProblems: true}))
			.fetch({success: function(data){self.buildTable();}});
	},
	buildTable: function () {
		this.$(".collection-table").remove();
		this.progressTable = new CollectionTableView({columnInfo: this.cols, collection: this.collection, 
                            paginator: {page_size: 10, button_class: "btn btn-default", row_class: "btn-group"}});
        this.progressTable.render().$el.addClass("table table-bordered table-condensed");
        this.$el.append(this.progressTable.el);

        // set up some styling
        this.progressTable.$(".paginator-row td").css("text-align","center");
        this.progressTable.$(".paginator-page").addClass("btn");
        this.clearFilterText();
        switch(this.model.get("type")){
			case "users":
				this.$(".login-name").addClass("hidden");
				break;
			case "sets":
				this.$(".set-id").addClass("hidden");
				break;
		}
	},
	getHelpTemplate: function () {

	},
	clearFilterText: function () {

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
            		$el.html(status + "/" + total);
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
