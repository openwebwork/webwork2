/**
 *  This is the HWDetailView, which is part of the HomeworkManagmentView.  The view contains the interface to all of the
 *  details of a given homework set including the changing of HWSet properties and assigning of users. 
 *
 *  One must pass a ProblemSet as a model to this.  
 * 
 **/


define(['Backbone', 
    'underscore',
    'views/EditableCell',
    'views/ProblemListView',
    'models/ProblemList',
    'models/ProblemSet',
    'views/UserListView',
    'models/OverrideList', 'config','bootstrap'], 
    function(Backbone, _,EditableCell,ProblemListView,ProblemList,ProblemSet,UserListView,PropertySetOverrideList, config){
	var HWDetailView = Backbone.View.extend({
        className: "set-detail-view",
        tagName: "div",
        initialize: function () {
            _.bindAll(this,'render','changeHWSet','updateNumProblems');
            this.users = this.options.users; 
            this.allProblemSets = this.options.problemSets;
            this.problemSet = this.model;

            this.problemViewAttrs = {reorderable: true, showPoints: true, showAddTool: false, showEditTool: true,
                    showRefreshTool: true, showViewTool: true, showHideTool: false, deletable: true, draggable: false};

            this.views = {
                problemListView : new ProblemListView({headerTemplate: "#problem-set-header", viewAttrs: this.problemViewAttrs}),
                usersAssignedView : new AssignUsersView({problemSet: this.problemSet, users: this.users}),
                propertiesView : new ProblemSetDetailView({users: this.users, problemSet: this.problemSet}),
                customizeUserAssignView : new CustomizeUserAssignView({users: this.users, problemSet: this.problemSet}),
                unassignUsersView: new UnassignUserView({users:this.users})
            };


            
        },
        render: function () {
            var self = this;
            this.$el.html(_.template($("#HW-detail-template").html()));
            
            this.views.problemListView.displayModes = config.settings.getSettingValue("pg{displayModes}");
            this.views.problemListView.setElement($("#problem-list-tab"));
            this.views.usersAssignedView.setElement($("#user-assign-tab"));
            this.views.propertiesView.setElement($("#property-tab"));
            this.views.customizeUserAssignView.setElement($("#user-customize-tab")); 
            this.views.unassignUsersView.setElement($("#user-unassign-tab"));     
        },
        events: {"shown a[data-toggle='tab']": "changeView"},
        changeView: function(evt){
            this.views[$(evt.target).data("view")].setProblemSet(this.problemSet).render();
        },
        changeHWSet: function (setName)
        {
            $("#problem-set-tabs a:first").tab("show");  // shows the properties tab
        	this.problemSet = this.allProblemSets.findWhere({set_id: setName});
            this.$("#problem-set-name").html("<h2>Problem Set: "+setName+"</h2>");
            this.views.propertiesView.setProblemSet(this.problemSet).render();
            this.loadProblems();
        },
        loadProblems: function () {
            var self = this;
            if(this.problemSet.problems){ // have the problems been fetched yet? 
                console.log("Loading the problems for set " + this.problemSet.get("set_id"));
                this.views.problemListView.setProblems(this.problemSet.problems);
                this.views.problemListView.render();
                this.updateNumProblems();
                this.problemSet.problems.on("num-problems-updated", self.updateNumProblems);


                // This sets messages  pstaab: move this to HW Manager. 
                /*
                this.problemSet.problems.on("deleteProblem",function (setName,place) {
                    var str = "Problem #" + (place +1) + " deleted from set: " + setName + " <br> "
                            + "To undo this, click the Undo button above the problem list. "; 
                    self.hwManager.announce.addMessage({text: str});
                });

                this.problemSet.problems.on("remove",self.updateNumProblems);
                this.problemSet.on("change",function(model)
                {
                    _.chain(model.changed).pairs().each(function(p){
                        self.hwManager.announce.addMessage({text: "The value of " + p[0] + " has changed to " + p[1]});

                    });
                    // need a announcement here.  
                    
                })

                this.problemSet.on("usersAssigned",function(_users,setName){
                    self.hwManager.announce.addMessage({text: "The following users are a assigned to set " + setName + " : " + _users.join(", ")});
                    var view = $("#setDetails .tab-content .active").data("view");
                    self.views[view].render(); 
                });


                
                this.problemSet.on("problem-set-changed", function (set){
                    //self.hwManager.announce.addMessage({text: "Something changed. "});
                }); */
            
            } else {
                this.problemSet.problems = new ProblemList({type: "Problem Set", setName: this.problemSet.get("set_id")});
                this.problemSet.problems.on("fetchSuccess",function() {self.loadProblems()});
            }


        },
        updateNumProblems: function () {
            console.log("in updateNumProblems");
            $("#number-of-problems").html("# of Probs Shown:" + $("#prob-list li").length + " of "
                    + this.problemSet.problems.length);
        }
    });

    var ProblemSetDetailView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this,'render','setProblemSet');
            this.users = this.options.users;

        },
        render: function () {
            this.$el.html($("#set-properties-tab-template").html());
            this.stickit();
            return this;
        },
        events: {"click .assign-all-users": "assignAllUsers"},
        assignAllUsers: function(){
            var userNames = this.users.pluck("user_id");
            this.model.assignToUsers(_.difference(userNames,this.model.get("assigned_users")));
        },
        setProblemSet: function(_set) {
            var self = this; 
            this.model = _set; 
            this.model.on("change",function () { self.model.update();});

            return this;
        },
        bindings: { ".open-date" : "open_date",
                    ".due-date" : "due_date",
                    ".answer-date": "answer_date",
                    ".set-visible": {observe: "visible", selectOptions: {
                        collection : [{value: 0, label: "No"},{value: 1, label: "Yes"}]
                    }},
                    ".reduced-credit": {observe: "reduced_credit_enabled", selectOptions: {
                        collection : [{value: 0, label: "No"},{value: 1, label: "Yes"}]
                    }},
                    ".users-assigned": {
                        observe: "assigned_users",
                        onGet: function(value, options){ return value.length + "/" +this.users.size();}
                    }
                }

    });

	var AssignUsersView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this,'render','selectAll','assignUsers','setProblemSet');
            this.users = this.options.users;
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },


        render: function() {
            this.$el.html($("#assign-users-template").html());
            this.stickit();
            return this;
        },
         events: {  "click .assign-button": "assignUsers",
                    "click .select-all": "selectAll"
        },
        bindings: { ".user-list": {observe: "assigned_users", 
            selectOptions: { collection: "this.userList", disabledCollection: "this.originalAssignedUsers"},   
            }
        },
        setProblemSet: function(_set) {
            this.problemSet = _set; 
            this.model = new ProblemSet(_set.attributes);
            this.originalAssignedUsers = this.model.get("assigned_users");
            this.originalUnassignedUsers = _(this.users.pluck("user_id")).difference(this.originalAssignedUsers);
            this.model.set("assigned_users",[]);

            return this;
        },
        selectAll: function (){
            this.model.set("assigned_users",this.$(".select-all").prop("checked")?
                            this.originalUnassignedUsers: []);
        },
        assignUsers: function(){
            this.problemSet.set("assigned_users",_(this.originalAssignedUsers).union(this.model.get("assigned_users")));
            this.problemSet.update();
            this.setProblemSet(this.problemSet);
            this.render();
            
        }
    });


    var CustomizeUserAssignView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this,'render','selectAll','saveChanges','setProblemSet');
            this.users = this.options.users;
            this.model = this.options.problemSet ? new ProblemSet(this.options.problemSet.attributes): null;
            this.overrides = null;
            this.rowTemplate = $("#customize-user-row-template").html();
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },
        render: function() {
            var self = this;
            this.$el.html($("#custom-assign-tmpl").html());
            
            if (this.overrides){
                // render the overrides
                var table = this.$("#customize-problem-set tbody").html("");
                this.stickit();
                this.overrides.each(function(override){
                    table.append((new CustomizeUsersRowView({rowTemplate: self.rowTemplate, model: override})).render().el);
                })
            } else {
                this.overrides = new PropertySetOverrideList(this.model);
                this.overrides.fetch().on("fetchSuccess",this.render);
            }
            return this;
        },
         events: {  "click .save-changes": "saveChanges",
                    "click #unassign-users": "unassignUsers",
                    "click #custom-select-all": "selectAll"
        },
        bindings: { ".open-date" : "open_date",
                    ".due-date": "due_date",
                    ".answer-date": "answer_date"
        },
        setProblemSet: function(_set) {
            this.model = new ProblemSet(_set.attributes); 
            this.overrides = null;
            return this;
        },
        saveChanges: function (){
            var self = this;
            var models = this.$(".user-select:checked").closest("tr")
                            .map(function(i,v) { return self.overrides.get($(v).data("cid"));}).get();
            _(models).each(function(_model){
                _model.set({open_date: self.model.get("open_date"), due_date: self.model.get("due_date"),
                            answer_date: self.model.get("answer_date")});
                console.log(_model);
                _model.update();
            })
        },
        selectAll: function (){
            this.$(".user-select").prop("checked",$("#custom-select-all").prop("checked"));

        }
    });

    var CustomizeUsersRowView = Backbone.View.extend({
        tagName: "tr",
        initialize: function() {
            _.bindAll(this,"render","save");
            this.template = this.options.rowTemplate;
            this.model.on("change",this.save);
        },
        render: function(){
            this.$el.html(this.template);
            this.$el.data("cid",this.model.cid);
            this.stickit();
            return this;
        },
        bindings: { ".user-id": "user_id",
                    ".open-date" : "open_date",
                    ".due-date": "due_date",
                    ".answer-date": "answer_date",
        },
        save: function(){
            this.model.update();
        }
    });

    var UnassignUserView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this,'render','selectAll','unassignUsers','setProblemSet');
            this.users = this.options.users;
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },


        render: function() {
            this.$el.html($("#unassign-users-template").html());
            this.stickit();
            return this;
        },
         events: {  "click .unassign-button": "unassignUsers",
                    "click .select-all": "selectAll"
        },
        bindings: { ".user-list": {observe: "assigned_users", 
            selectOptions: { collection: "this.userList", disabledCollection: "this.unassignedUsers"},   
            }
        },
        setProblemSet: function(_set) {
            this.problemSet = _set; 
            this.originalAssignedUsers = this.problemSet.get("assigned_users");
            this.unassignedUsers = _(this.users.pluck("user_id")).difference(this.originalAssignedUsers);
            this.model = new ProblemSet(_set.attributes);
            this.model.set("assigned_users",[]);
            return this;
        },
        selectAll: function (){
            this.model.set("assigned_users",this.$(".select-all").prop("checked")?
                            this.originalAssignedUsers: []);
        },
        unassignUsers: function(){
            var currentUsers = _(this.originalAssignedUsers).difference(this.model.get("assigned_users"));
            var confirmDelete = confirm("You have selected to delete the following users: " 
                    + this.model.get("assigned_users").join(", ")+". Click OK to confirm this.  Removing a user " 
                    + "will remove all data associated with the user and this problem set.");
            if (confirmDelete){
                this.problemSet.set("assigned_users",currentUsers);
                this.problemSet.update();
                this.model.set("assigned_users",[]);
                this.render();
            }
        }
    });

        
	return HWDetailView;
});