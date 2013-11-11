/**
 *  This is the ProblemSetDetailView.  The view contains the interface to all of the
 *  details of a given homework set including the changing of HWSet properties and assigning of users. 
 *
 *  One must pass a ProblemSet as a model to this.  
 * 
 **/


define(['Backbone','underscore','views/ProblemSetView','models/ProblemList',
    'models/ProblemSet','views/UserListView','models/UserSetList', 'config','bootstrap'], 
    function(Backbone, _,ProblemSetView,ProblemList,ProblemSet,UserListView,
        UserSetList, config){
	var ProblemSetDetailsView = Backbone.View.extend({
        className: "set-detail-view",
        tagName: "div",
        initialize: function (options) {
            _.bindAll(this,'render','changeHWSet','updateNumberOfProblems','loadProblems');
            var self = this;
            this.users = options.users; 
            this.allProblemSets = options.problemSets;
            this.problemSet = this.model;
            this.headerView = options.headerView;

            
            this.views = {
                problemSetView : new ProblemSetView({problemSet: this.problemSet}),
                usersAssignedView : new AssignUsersView({problemSet: this.problemSet, users: this.users}),
                propertiesView : new DetailsView({users: this.users, problemSet: this.problemSet}),
                customizeUserAssignView : new CustomizeUserAssignView({users: this.users, problemSet: this.problemSet}),
                unassignUsersView: new UnassignUserView({users:this.users})
            };

            this.headerInfo={ template: "#setDetails-header", 
                events: {"show.bs.tab a[data-toggle='tab']": function(evt) { self.changeView(evt);} }};    

            
            this.views.problemSetView.on("update-num-problems",this.updateNumberOfProblems);

            
        },
        render: function () {
            var self = this;
            this.$el.html($("#HW-detail-template").html());
            
            this.views.problemSetView.setElement($("#problem-list-tab"));
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
            if(this.problemSet.get("problems")){ // have the problems been fetched yet? 
                this.views.problemSetView.set({problems: this.problemSet.get("problems"),
                    problemSet: this.problemSet});
            } else {
                this.problemSet.set("problems",ProblemList({setName: this.problemSet.get("set_id")}))
                    .get("problems").fetch({success: this.loadProblems});
            }
        },       
        updateNumberOfProblems: function (text) {
            this.headerView.$(".number-of-problems").html(text);
        }
    });

    var DetailsView = Backbone.View.extend({
        initialize: function (options) {
            _.bindAll(this,'render','setProblemSet');
            this.users = options.users;

        },
        render: function () {
            this.$el.html($("#set-properties-tab-template").html());
            this.stickit();
            return this;
        },
        events: {"click .assign-all-users": "assignAllUsers"},
        assignAllUsers: function(){
            this.model.set({assigned_users: this.users.pluck("user_id")});
        },
        setProblemSet: function(_set) {
            var self = this; 
            this.model = _set; 
            return this;
        },
        bindings: { ".set-name" : "set_id",
                    ".open-date" : "open_date",
                    ".due-date" : "due_date",
                    ".answer-date": "answer_date",
                    ".prob-set-visible": {observe: "visible", selectOptions: {
                        collection : [{value: "0", label: "No"},{value: "1", label: "Yes"}]
                    }},
                    ".reduced-credit": {observe: "enable_reduced_scoring", selectOptions: {
                        collection : [{value: "0", label: "No"},{value: "1", label: "Yes"}]
                    }},
                    ".users-assigned": {
                        observe: "assigned_users",
                        onGet: function(value, options){ return value.length + "/" +this.users.size();}
                    }
                }

    });

	var AssignUsersView = Backbone.View.extend({
        initialize: function (options) {
            _.bindAll(this,'render','selectAll','assignUsers','setProblemSet');
            this.users = options.users;
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },


        render: function() {
            this.$el.html(_.template($("#assign-users-template").html(),{setname: this.model.get("set_id")}));
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
            var self = this; 
            this.problemSet = _set; 
            this.model = new ProblemSet(_set.attributes);
            this.model.set("assigned_users",[]);
            this.updateModel();
            this.problemSet.on("change", function(){
                self.updateModel();
                self.render();
            });

            return this;
        },
        updateModel: function () {
            this.originalAssignedUsers = this.problemSet.get("assigned_users");
            this.originalUnassignedUsers = _(this.users.pluck("user_id")).difference(this.originalAssignedUsers);
        },
        selectAll: function (){
            this.model.set("assigned_users",this.$(".select-all").prop("checked")?
                            this.originalUnassignedUsers: []);
        },
        assignUsers: function(){
            this.problemSet.set("assigned_users",_(this.originalAssignedUsers).union(this.model.get("assigned_users")));
        }
    });


   

    var UnassignUserView = Backbone.View.extend({
        initialize: function (options) {
            _.bindAll(this,'render','selectAll','unassignUsers','setProblemSet');
            this.users = options.users;
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },


        render: function() {
            this.$el.html(_.template($("#unassign-users-template").html(),{setname: this.model.get("set_id")}))
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
            var self = this; 
            this.problemSet = _set; 
            this.model = new ProblemSet(_set.attributes);
            this.model.set("assigned_users",[]);
            this.updateModel();
            this.problemSet.on("change", function(){
                self.updateModel();
                self.render();
            });

            return this;
        },
        updateModel: function () {
            this.originalAssignedUsers = this.problemSet.get("assigned_users");
            this.unassignedUsers = _(this.users.pluck("user_id")).difference(this.originalAssignedUsers);
        },
        selectAll: function (){
            this.model.set("assigned_users",this.$(".select-all").prop("checked")?
                            this.originalAssignedUsers: []);
        },
        unassignUsers: function(){
            var self = this;
            var currentUsers = _(this.originalAssignedUsers).difference(this.model.get("assigned_users"));
            var confirmDelete = confirm(config.msgTemplate({type: "unassign_users", 
                    opts: {users: this.model.get("assigned_users").join(", ")}}));
            if (confirmDelete){
                this.problemSet.set("assigned_users",currentUsers);
                this.problemSet.save();
            }
        }
    });

 var CustomizeUserAssignView = Backbone.View.extend({
        initialize: function (options) {
            _.bindAll(this,'render','selectAll','saveChanges','setProblemSet');
            this.users = options.users;
            this.problemSet = options.problemSet;
            this.model = options.problemSet ? new ProblemSet(options.problemSet.attributes): null;
            this.userSetList = null;
            this.rowTemplate = $("#customize-user-row-template").html();
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },
        render: function() {
            var self = this;
            this.$el.html(_.template($("#custom-assign-template").html(),{setname: this.model.get("set_id")}))

            
            if (this.userSetList){

                var table = this.$("#customize-problem-set tbody").empty();
                this.stickit();
                this.userSetList.each(function(userSet){
                    table.append((new CustomizeUsersRowView({rowTemplate: self.rowTemplate, model: userSet})).render().el);
                })
                this.problemSet.trigger("user_sets_added",this.userSetList);
                
            } else {
                (this.userSetList = new UserSetList([],{problemSet: this.model}));
                this.userSetList.fetch({success: this.render});
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
            this.problemSet = _set;
            this.model = new ProblemSet(_set.attributes); 
            this.userSetList = null;
            return this;
        },
        saveChanges: function (){
            var self = this;
            var models = this.$(".user-select:checked").closest("tr")
                            .map(function(i,v) { return self.userSetList.get($(v).data("cid"));}).get();
            _(models).each(function(_model){
                _model.set({open_date: self.model.get("open_date"), due_date: self.model.get("due_date"),
                            answer_date: self.model.get("answer_date")});
            });
        },
        selectAll: function (){
            this.$(".user-select").prop("checked",$("#custom-select-all").prop("checked"));

        }
    });

    var CustomizeUsersRowView = Backbone.View.extend({
        tagName: "tr",
        initialize: function(options) {
            var self = this;
            _.bindAll(this,"render");
            this.template = options.rowTemplate;
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
        }
    });
        
	return ProblemSetDetailsView;
});