/**
 *  This is the ProblemSetDetailView.  The view contains the interface to all of the
 *  details of a given homework set including the changing of HWSet properties and assigning of users. 
 *
 *  One must pass a ProblemSet as a model to this.  
 * 
 **/


define(['backbone','underscore','views/MainView','views/ProblemSetView','models/ProblemList','views/CollectionTableView',
    'models/ProblemSet','models/UserSetListOfUsers', 'config','bootstrap'], 
    function(Backbone, _,MainView,ProblemSetView,ProblemList,CollectionTableView,ProblemSet,
        UserSetListOfUsers, config){
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
        events: {"shown.bs.tab #problem-set-tabs a[data-toggle='tab']": "changeView"},
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

    // Trying a new UI for this View

    var CustomizeUserAssignView = Backbone.View.extend({
        initialize: function(options){
            _.bindAll(this,"render","updateTable","saveChanges","filter","buildCollection");
            this.model = this.model = options.problemSet ? new ProblemSet(options.problemSet.attributes): null;
            this.users = options.users;
            this.tableSetup();

          
        },
        render: function () {
            var self = this;
            this.$el.html($("#loading-usersets-template").html());
            if (this.collection.size()>0){
                this.$el.html($("#cutomize-assignment-template").html());
                (this.userSetTable = new CollectionTableView({columnInfo: this.cols, collection: this.collection, 
                        paginator: {showPaginator: false}, tablename: ".users-table"}))
                    .render().$el.addClass("table table-bordered table-condensed");
                this.$el.append(this.userSetTable.el);
                this.stickit();
            } else {
                this.UserSetListOfUsers.fetch({success: function () {self.buildCollection(); self.render();}});
            }
        },
        events: {"change .show-section,.show-recitation": "updateTable",
            "click .save-changes": "saveChanges",
            "keyup .search-box": "filter",
            "change th[data-class-name='select-user'] input": "selectAllUsers"
        },
        bindings: { "#customize-problem-set-controls .open-date" : "open_date",
                    "#customize-problem-set-controls .due-date": "due_date",
                    "#customize-problem-set-controls .answer-date": "answer_date"
        },
        selectAllUsers: function(evt){
            $("table.users-table input[type='checkbox']").prop("checked", $(evt.target).prop("checked"));
        },
        filter: function(evt) {
            var str = $(evt.target).val()
                , match = str.match(/(\w+):(\w+)/)
                , obj={}; 
            if(match){
                obj[match[1]]=match[2];
                this.userSetTable.filter(obj).render();
            } else {
                this.userSetTable.filter(str).render();    
            }
        },
        saveChanges: function (){
            var self = this;
            _($(".select-user input:checked").siblings(".user-id").map(function(i,v) { 
                    return self.UserSetListOfUsers.findWhere({user_id: $(v).val()});
                })).each(function(_model){
                    _model.set(self.model.pick("open_date","due_date","answer_date"));
                });
        },
        updateTable: function (){
            this.tableSetup({show_recitation: this.$(".show-recitation").prop("checked"), 
                    show_section: this.$(".show-section").prop("checked")});
            this.userSetTable.setColumns(this.cols).render();
        },
        setProblemSet: function(_set) {
            this.problemSet = _set;  // this is the globalSet
            this.model = new ProblemSet(_set.attributes);  // this is used to pull properties for the userSets.  We don't want to overwrite the properties in this.problemSet
            this.UserSetListOfUsers = new UserSetListOfUsers([],{problemSet: this.model});
            this.UserSetListOfUsers.on({change: function(model){model.save();}});
            // make a new collection that merges the UserSetListOfUsers and the userList 
            this.collection = new Backbone.Collection();
            return this;
        }, 
        buildCollection: function(){ // since the collection needs to contain a mixture of userSet and user properties, we merge them. 
            var self = this;
            this.collection.reset(this.UserSetListOfUsers.models);
            this.collection.each(function(model){
                model.set(self.users.findWhere({user_id: model.get("user_id")}).pick("section","recitation"));
            });
            this.collection.on({change: function(model){
                self.UserSetListOfUsers.findWhere({user_id: model.get("user_id")}).set(model.pick("open_date","due_date","answer_date")).save();
            }});

            return this;
        },
        tableSetup: function (opts) {
            var self = this;
            this.cols = [
                {name: "Select", key: "select-user", classname: "select-user", 
                    stickit_options: {update: function($el, val, model, options) {
                        $el.html($("#checkbox-template").html());
                        $el.children(".user-id").val(model.get("user_id"));
                    }},
                    colHeader: "<input type='checkbox'></input>"
                },
                {name: "Student", key: "user_id", classname: "student",
                    stickit_options: {update: function($el,val,model,options){
                        var user = self.users.findWhere({user_id: val});
                        $el.html(_.template($("#user-name-template").html(),user.attributes));
                    }}},
                {name: "Open Date", key: "open_date", classname: ["open-date","edit-datetime"], 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Due Date", key: "due_date", classname: ["due-date","edit-datetime"], 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Answer Date", key: "answer_date", classname: ["answer-date","edit-datetime"], 
                        editable: false, datatype: "integer", use_contenteditable: false}
                ];
                if(opts && opts.show_section){
                    this.cols.push({name: "Section", key: "section", classname: "section", editable: false,
                        datatype: "string"});
                }
                if(opts && opts.show_recitation){
                    this.cols.push({name: "Recitation", key: "recitation", classname: "recitation", editable: false,
                        datatype: "string"});
                }
        }

    });
// This is the old UI 
/* var CustomizeUserAssignView = Backbone.View.extend({
        initialize: function (options) {
            _.bindAll(this,'render','selectAll','saveChanges','setProblemSet');
            this.users = options.users;
            this.problemSet = options.problemSet;
            this.model = options.problemSet ? new ProblemSet(options.problemSet.attributes): null;
            this.UserSetListOfUsers = null;
            this.rowTemplate = $("#customize-user-row-template").html();
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },
        render: function() {
            var self = this;
            this.$el.html(_.template($("#custom-assign-template").html(),{setname: this.model.get("set_id")}))

            
            if (this.UserSetListOfUsers){

                var table = this.$("#customize-problem-set tbody").empty();
                this.stickit();
                this.UserSetListOfUsers.each(function(userSet){
                    table.append((new CustomizeUsersRowView({rowTemplate: self.rowTemplate, model: userSet})).render().el);
                })
                this.problemSet.trigger("user_sets_added",this.UserSetListOfUsers);
                
            } else {
                (this.UserSetListOfUsers = new UserSetListOfUsers([],{problemSet: this.model}));
                this.UserSetListOfUsers.fetch({success: this.render});
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
            this.UserSetListOfUsers = null;
            return this;
        },
        saveChanges: function (){
            var self = this;
            var models = this.$(".user-select:checked").closest("tr")
                            .map(function(i,v) { return self.UserSetListOfUsers.get($(v).data("cid"));}).get();
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
    }); */
        
	return ProblemSetDetailsView;
});