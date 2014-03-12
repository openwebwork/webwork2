//  This is the main view for the Student Progress Page.

define(['backbone', 'underscore','views/MainView','config','views/CollectionTableView','models/UserSetList'], 
function(Backbone, _,MainView,config,CollectionTableView,UserSetList){
var StudentProgressView = MainView.extend({
	initialize: function (options){
		_(this).bindAll("loadData");
		this.problemSets = options.problemSets;
		this.users = options.users;
		this.tableSetup();
		this.displayType = "sets";

	},
	render: function (){
		this.$el.html($("#student-progress-template").html());
		this.changeDisplay("Sets");
	    return this;
	},
	events: {
		"click .progress-menu a": "loadData",
		"click .change-display-type a": "changeDisplay"
	},
	changeDisplay: function(evt){
		this.displayType = _.isString(evt)? evt.toLowerCase(): $(evt.target).text().toLowerCase();
		this.$(".progress-type .type-name").text(_.isString(evt)? evt: $(evt.target).text());
		var menu = this.$(".progress-menu").empty();
		this.$(".collection-table").remove();
		var menuItem = _.template($("#progress-menu-item").html());

		if(this.displayType==="sets"){
			this.$(".progress-menu-header .name").text("Select Set...");
			this.problemSets.each(function(_set){
				menu.append(menuItem({name: _set.get("set_id")}));  // add to a template. 
			});
			this.cols[0] = {name: "Login Name", key: "user_id", classname: "login-name", datatype: "string"};
		} else {
			this.$(".progress-menu-header .name").text("Select User...");
			this.users.each(function(_user){
				menu.append(menuItem({name: _user.get("user_id")}));  // add to a template. 
			});
			this.cols[0] = {name: "Set Name", key: "set_id", classname: "set-id", datatype: "string"};
		}
	},
	loadData: function(evt) {
		var self = this;
		this.$(".progress-menu-header .name").text($(evt.target).data("name"));
		if(this.displayType==="sets"){
			var _set = this.problemSets.findWhere({set_id: $(evt.target).data("name")});
			(this.collection = new UserSetList([],{problemSet: _set, type: "users",loadProblems: true}))
						.fetch({success: function (data){self.buildTable();}});
		} else {
			var _user = this.users.findWhere({user_id: $(evt.target).data("name")});
			(this.collection = new UserSetList([],{user: _user.get("user_id"), type: "sets", loadProblems: true}))
				.fetch({success: function(data){self.buildTable();}});
		}

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
	},
	getHelpTemplate: function () {

	},
	clearFilterText: function () {

	},
	tableSetup: function () {
        var self = this;
        this.cols = [
            {name: "Login Name", key: "user_id", classname: "login-name", datatype: "string"},
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
