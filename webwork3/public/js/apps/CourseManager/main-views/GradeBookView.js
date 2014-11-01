//  This is the main view for the Student Progress Page.

define(['backbone', 'underscore','views/MainView','config','views/CollectionTableView','models/GradeBook','models/UserSetList'], 
function(Backbone, _,MainView,config,CollectionTableView,GradeBook,UserSetList){
var GradeBookView = MainView.extend({
	initialize: function (options){
		var self = this;
		_(this).bindAll("buildTable","render","changeDisplay");	
		MainView.prototype.initialize.call(this,options);	
		console.log(options);		
		this.tableSetup();			
		this.state.on({
			"change:type": this.changeDisplay, 
			"change:set_id change:type": this.buildTable,
		})	
	},
	render: function (){
		var self = this;		
		this.$el.html($("#gradebook-template").html());		
		this.stickit(this.state);		
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
		} else {
			console.log('There was no collection passed into CollectionTableView');
		}
		MainView.prototype.render.apply(this);							
	    return this;
	},
	getDefaultState: function () {
		return {set_id: "", user_id: "", type: "gradebook", page_num: 0};
	},
	changeDisplay: function(){
		var self = this;
		this.$(".collection-table").remove();
		switch(this.state.get("type")){
			case "sets":
				this.tableSetup();
				break;
			case "users":
				this.tableSetup();
				break;
		}
	},	
	buildTable: function () {
		var self = this;
		console.log(this.state.get("type"));
		if (this.state.get("type")==="sets"){
				(this.collection = new UserSetList([],{user: self.state.get("user_id"), type: "sets", loadProblems: true}))
				.fetch({success: function(data){self.render();}});	
		} else if (this.state.get("type")==="users"){
				(this.collection = new UserSetList([],{problemSet: _set, type: "users",loadProblems: true}))
					.fetch({success: function (data){self.render();}});	
		} else if (this.state.get("type")==="gradebook"){				
				this.collection = new GradeBook([],{type: "gradebook",loadProblems: true});		
				this.collection.fetch({success: function (data){
					var admin_model = self.collection.get("admin");		
	    	    	var admin_model_keys = _.keys(admin_model['attributes']);
    	    		var setnames = _.without(admin_model_keys,'user_id');  
       				_.each(setnames, function(name){
	       				self.cols.push({name: name.split('_')[0], key: name, classname: name, datatype: "integer"});
		       		});	      	
				self.render();}});		
		}
	},	
	getHelpTemplate: function () {
		//Help template goes here?
	},	
	tableSetup: function () {
        var self = this;
        console.log(this.state);        
        switch(this.state.get('type')){
        	case "gradebook":
        		this.cols = [{name: "Login Name", key: "user_id", classname: "login-name", datatype: "string",
        		    stickit_options: {update: function($el, val, model, options) {
                    	$el.html("<a href='#' onclick='return false' class='goto-user' data-username='"+val+"'>" + val + "</a>");
                    	$el.children("a").on("click",function() {  
                    		console.log(val);
                    		console.log($(this).data('username'));
                    		self.state.set({user_id: $(this).data('username')});
                    		console.log(self.state);                    	               	                  	
                    		self.state.set({type: "sets"});
                    	});}
                	}
        		}];
        		this.buildTable();        
				break;
			case "users":
				console.log('users');
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
			  break;	
			case "sets":
			this.cols = [
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
			  break;				  
    	}
    }

});

return GradeBookView;
});
