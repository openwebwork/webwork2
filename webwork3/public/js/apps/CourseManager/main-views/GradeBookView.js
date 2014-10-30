//  This is the main view for the Student Progress Page.

define(['backbone', 'underscore','views/MainView','config','views/CollectionTableView','models/GradeBook'], 
function(Backbone, _,MainView,config,CollectionTableView,GradeBook){
var GradeBookView = MainView.extend({
	initialize: function (options){
		var self = this;
		_(this).bindAll("render");
		MainView.prototype.initialize.call(this,options);
		this.tableSetup();
	},
	render: function (){
		var self = this;
		this.$(".collection-table").remove();		
		this.$el.html($("#gradebook-template").html());
		this.stickit(this.state,this.bindings);
		if(this.collection){
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
	getDefaultState: function () {
		return {set_id: "", user_id: "", type: "gradebook", page_num: 0};
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
	getHelpTemplate: function () {

	},
	tableSetup: function () {
        var self = this;
        this.cols = [
            {name: "Login Name", key: "user_id", classname: "login-name", datatype: "string"}
        ];        
		this.collection = new GradeBook([],{type: "gradebook",loadProblems: true});		
		this.collection.fetch({success: function (data){
			console.log(self.collection);
			var admin_model = self.collection.get("admin");
        	console.log(admin_model);			
        	var admin_model_keys = _.keys(admin_model['attributes']);
        	setnames = _.without(admin_model_keys,'user_id');  
       		var set_columns = _.each(setnames, function(name){
       			self.cols.push({name: name.split('_')[0], key: name, classname: name, datatype: "integer"});
       		});
       		console.log(self.cols);		      	
			self.render();}});
    }

});

return GradeBookView;
});
