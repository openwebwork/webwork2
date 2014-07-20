/**
 *  This is the ProblemSetDetailView.  The view contains the interface to all of the
 *  details of a given homework set including the changing of HWSet properties and assigning of users. 
 *
 *  One must pass a ProblemSet as a model to this.  
 * 
 **/


define(['backbone','underscore','views/TabbedMainView','views/ProblemSetView','models/ProblemList',
    'views/CollectionTableView','models/ProblemSet','models/UserSetList', 'config','bootstrap'], 
    function(Backbone, _,TabbedMainView,ProblemSetView,ProblemList,CollectionTableView,ProblemSet,
        UserSetList, config){
	var ProblemSetDetailsView = TabbedMainView.extend({
        className: "set-detail-view",
        messageTemplate: _.template($("#problem-sets-manager-messages-template").html()),
        initialize: function(options){
            var self = this;

            this.views = options.views = {
                propertiesView : new DetailsView({users: options.users, settings: options.settings}),
                problemsView : new ProblemSetView({settings: options.settings, messageTemplate: this.messageTemplate}),
                usersAssignedView : new AssignUsersView({users: options.users}),
                unassignUsersView: new UnassignUserView({users: options.users}),
                customizeUserAssignView : new CustomizeUserAssignView({users: options.users,
                        eventDispatcher: this.eventDispatcher, settings: options.settings})
            };
            this.views.problemsView.on("page-changed",function(num){
                self.eventDispatcher.trigger("save-state");
            })

            options.tabs = ".set-details-tab";
            options.tabContent = ".set-details-tab-content";
            this.model = new Backbone.Model({set_id: ""});
            this.model.on("change:set_id", function() {
                self.changeProblemSet(self.model.get("set_id"));
            })
            TabbedMainView.prototype.initialize.call(this,options)
        },
        bindings: {
            ".problem-set-name": {observe: "set_id", selectOptions: {
                collection: function () {
                    return this.problemSets.pluck("set_id");
                },
                defaultOption: {label: "Select Set...", value: ""}
            }}
        },
        render: function(){
            this.$el.html($("#HW-detail-template").html());
            this.stickit();
            TabbedMainView.prototype.render.call(this);            
        },
        getHelpTemplate: function () {
            switch(this.currentViewName){
                case "propertiesView":
                    return $("#problem-set-details-help-template").html();
                case "problemsView":
                    return $("#problem-set-view-help-template").html();
                case "customizeUserAssignView":
                    return $("#customize-assignment-help-template").html();
                case "assignUsersView":
                    return $("#problem-set-assign-users-help-template").html();
            }
        },
        originalEvents: {

        }, 
        sidebarEvents: {
            "change-display-mode": function(evt) { 
                if(_.isFunction(this.views[this.currentViewName].changeDisplayMode)){
                    this.views[this.currentViewName].changeDisplayMode(evt);
                }},
            "show-hide-tags": function(evt){
                if(_.isFunction(this.views[this.currentViewName].toggleTags)){
                    this.views[this.currentViewName].toggleTags(evt);
            }},
            "show-hide-path": function(evt){
                if(_.isFunction(this.views[this.currentViewName].toggleShowPath)){
                    this.views[this.currentViewName].toggleShowPath(evt);
            }},
        },
        getState: function () {
            var state = TabbedMainView.prototype.getState.call(this);
            if(this.model.get("set_id")){
                state.set_id = this.model.get("set_id");
            }
            return state;
        },
        setState: function(_state){
            if(_state && _state.set_id){
                this.model.set("set_id",_state.set_id);
                this.changeProblemSet(_state.set_id);
                this.currentViewName = _state.subview;
            }
            TabbedMainView.prototype.setState.call(this,_state);
            return this;
        },
        changeProblemSet: function (setName)
        {
            var self = this;
            this.model.set("set_id",setName);
        	this.problemSet = this.problemSets.findWhere({set_id: setName});
            _(this.views).chain().keys().each(function(view){
                self.views[view].setProblemSet(self.problemSet);
            });
            this.views.problemsView.currentPage = 0; // make sure that the problems start on a new page. 
            this.changeView("propertiesView");
            this.loadProblems();
            return this;
        },
        loadProblems: function () {
            var self = this;
            if(this.problemSet.get("problems")){ // have the problems been fetched yet? 
                this.views.problemsView.set({problems: this.problemSet.get("problems"),
                    problemSet: this.problemSet});
            } else {
                this.problemSet.set("problems",ProblemList({setName: this.problemSet.get("set_id")}))
                    .get("problems").fetch({success: this.loadProblems});
            }
        },       
        updateNumberOfProblems: function (text) {
            this.headerView.$(".number-of-problems").html(text);
        },
        setMessages: function () {
            /* Set up all of the events on the user problemSets */

            var self = this;
            this.problemSets.on("user_sets_added",function(_userSetList){
                _userSetList.on(
                {
                    change: function(_userSet){
                        _userSet.changingAttributes=_.pick(_userSet._previousAttributes,_.keys(_userSet.changed));
                        _userSet.save();
                    },
                    sync: function(_userSet){  // note: this was just copied from HomeworkManager.js  perhaps a common place for this
                        _(_userSet.changingAttributes||{}).chain().keys().each(function(key){
                            var _old = key.match(/date$/)
                                        ? moment.unix(_userSet.changingAttributes[key]).format("MM/DD/YYYY [at] hh:mmA")
                                        : _userSet.changingAttributes[key];
                            var _new = key.match(/date$/) 
                                        ? moment.unix(_userSet.get(key)).format("MM/DD/YYYY [at] hh:mmA") 
                                        : _userSet.get(key);
                            self.eventDispatcher.trigger("add-message",{type: "success", 
                                short: self.messageTemplate({type:"set_saved",opts:{setname:_userSet.get("set_id")}}),
                                text: self.messageTemplate({type:"set_saved_details",opts:{setname:_userSet.get("set_id"),key: key,
                                    oldValue: _old, newValue: _new}})});
                        });
                    }
                }); //  _userSetList.on 
            })
        }
    });

    var DetailsView = Backbone.View.extend({
        viewName: "Set Details",
        initialize: function (options) {
            _.bindAll(this,'render','setProblemSet',"showHideReducedScoringDate");
            this.users = options.users;
            this.settings = options.settings;
        },
        render: function(){
            if(this.model){
                this.$el.html($("#set-properties-tab-template").html());
                this.showHideReducedScoringDate();
                this.stickit();
            }
            return this;
        },
        events: {
            "click .assign-all-users": "assignAllUsers",
            //"change .reduced-scoring": "showHideReducedScoringDate"
        },
        assignAllUsers: function(){
            this.model.set({assigned_users: this.users.pluck("user_id")});
        },
        setProblemSet: function(_set) {
            var self = this; 
            this.model = _set; 
            if(this.model){
                this.model.on("change:enable_reduced_scoring",this.render);
            }
            return this;
        },
        bindings: {
            ".set-name" : "set_id",
            ".open-date" : "open_date",
            ".due-date" : "due_date",
            ".answer-date": "answer_date",
            ".prob-set-visible": "visible",
            ".reduced-scoring": "enable_reduced_scoring",
            ".reduced-scoring-date": "reduced_scoring_date",
            ".users-assigned": {
                observe: "assigned_users",
                onGet: function(value, options){ return value.length + "/" +this.users.size();}
            }
        },
        showHideReducedScoringDate: function(){
            if(this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}") &&  
                    this.model.get("enable_reduced_scoring")) { // show reduced credit field
                this.$(".reduced-scoring-date").closest("tr").removeClass("hidden");

                // fill in a reduced_scoring_date if the field is empty or 0. 
                if(this.model.get("reduced_scoring_date")=="" || this.model.get("reduced_scoring_date")==0){
                    var rcDate = moment.unix(this.model.get("due_date")).subtract("minutes",
                        this.settings.getSettingValue("pg{ansEvalDefaults}{reducedScoringPeriod}"));
                    this.model.set({reduced_scoring_date: rcDate.unix()});
                }
            } else {
                this.$(".reduced-scoring-date").closest("tr").addClass("hidden");
            }
            if(this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}")){
                this.$(".reduced-scoring").closest("tr").removeClass("hidden")
            } else {
                this.$(".reduced-scoring").closest("tr").addClass("hidden")
            }
        }

    });

	var AssignUsersView = Backbone.View.extend({
        viewName: "Assign Users",
        initialize: function (options) {
            _.bindAll(this,'render','selectAll','assignUsers','setProblemSet');
            this.users = options.users;
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },


        render: function() {
            if(this.model){
                this.$el.html(_.template($("#assign-users-template").html(),{setname: this.model.get("set_id")}));
                this.stickit();
            }
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
            if(_set){
                this.model = new ProblemSet(_set.attributes);
                this.model.set("assigned_users",[]);
                this.updateModel();
                this.problemSet.on("change", function(){
                    self.updateModel();
                    self.render();
                });
            }

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
        viewName: "Unassign Users",
        initialize: function (options) {
            _.bindAll(this,'render','selectAll','unassignUsers','setProblemSet');
            this.users = options.users;
            this.userList = this.users.map(function(user){ 
                return {label: user.get("first_name") + " " + user.get("last_name"), value: user.get("user_id")}});
        },


        render: function() {
            if(this.model){
                this.$el.html(_.template($("#unassign-users-template").html(),{setname: this.model.get("set_id")}))
                this.stickit();            
            }
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
            if(_set){
                this.model = new ProblemSet(_set.attributes);
                this.model.set("assigned_users",[]);
                this.updateModel();
                this.problemSet.on("change", function(){
                    self.updateModel();
                    self.render();
                });
            }

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
            var confirmDelete = confirm(this.messageTemplate({type: "unassign_users", 
                    opts: {users: this.model.get("assigned_users").join(", ")}}));
            if (confirmDelete){
                this.problemSet.set("assigned_users",currentUsers);
                this.problemSet.save();
            }
        }
    });

    // Trying a new UI for this View

    var CustomizeUserAssignView = Backbone.View.extend({
        viewName: "Student Overrides",
        initialize: function(options){
            _.bindAll(this,"render","updateTable","saveChanges","filter","buildCollection","setProblemSet");

            // this.model is a clone of the parent ProblemSet.  It is used to save properties for multiple students.

            this.model = options.problemSet ? new ProblemSet(options.problemSet.attributes): null;
            _.extend(this,_(options).pick("users","settings","eventDispatcher"));
        },
        render: function () {
            var self = this;
            var reducedScoring = this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}") 
                && this.problemSet.get("enable_reduced_scoring"); 
            this.tableSetup({show_reduced_scoring: reducedScoring});
            this.$el.html($("#loading-usersets-template").html());

            if (this.collection.size()>0){
                this.$el.html($("#customize-assignment-template").html());
                (this.userSetTable = new CollectionTableView({columnInfo: this.cols, collection: this.collection, 
                        paginator: {showPaginator: false}, tablename: ".users-table"}))
                    .render().$el.addClass("table table-bordered table-condensed");
                this.$el.append(this.userSetTable.el);

                // show/hide the bottom row reduced-scoring
                if(this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}")){
                    this.$(".reduced-scoring-date,.reduced-scoring-header").removeClass("hidden")
                } else {
                    this.$(".reduced-scoring-date,.reduced-scoring-header").addClass("hidden")
                }

                this.stickit();
            } else {
                this.userSetList.fetch({success: function () {self.buildCollection(); self.render();}});
            }
        },
        events: {
            "change .show-section,.show-recitation": "updateTable",
            "click .save-changes": "saveChanges",
            "keyup .search-box": "filter",
            "change th[data-class-name='select-user'] input": "selectAllUsers"
        },
        bindings: { "#customize-problem-set-controls .open-date" : "open_date",
                    "#customize-problem-set-controls .due-date": "due_date",
                    "#customize-problem-set-controls .answer-date": "answer_date",
                    "#customize-problem-set-controls .reduced-scoring-date": "reduced_scoring_date"
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
                    return self.userSetList.findWhere({user_id: $(v).val()});
                })).each(function(_model){
                    _model.set(self.model.pick("open_date","due_date","answer_date","reduced_scoring_date"));
                });
        },
        updateTable: function (){
            this.tableSetup({show_recitation: this.$(".show-recitation").prop("checked"), 
                    show_section: this.$(".show-section").prop("checked")});
            this.userSetTable.setColumns(this.cols).render();
        },
        setProblemSet: function(_set) {
            this.problemSet = _set;  // this is the globalSet
            if(_set){
                this.model = new ProblemSet(_set.attributes);  // this is used to pull properties for the userSets.  We don't want to overwrite the properties in this.problemSet
                this.userSetList = new UserSetList([],{problemSet: this.model,type: "users"});
                this.userSetList.on("change:due_date change:answer_date change:open_date", function(model){
                    model.save();
                });
            }

            // make a new collection that merges the UserSetListOfUsers and the userList 
            this.collection = new Backbone.Collection();
            return this;
        }, 
        buildCollection: function(){ // since the collection needs to contain a mixture of userSet and user properties, we merge them. 
            var self = this;
            this.collection.reset(this.userSetList.models);
            this.collection.each(function(model){
                model.set(self.users.findWhere({user_id: model.get("user_id")}).pick("section","recitation"));
            });
            this.collection.on({change: function(model){
                console.log(moment.unix(model.get("reduced_scoring_date")).format("MM-DD-YYYY"));
                self.userSetList.findWhere({user_id: model.get("user_id")}).set(model.pick("open_date","due_date","answer_date")).save();
            }});
            this.setMessages();

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
                if(opts && opts.show_reduced_scoring){
                    this.cols.splice(3,0,{name: "Reduced Scoring Date", key: "reduced_scoring_date", 
                        classname: ["reduced-scoring-date","edit-datetime"], editable: true,
                        datatype: "integer"});
                }
        },
        messageTemplate: _.template($("#customize-users-messages-template").html()),
        setMessages: function(){
            var self = this;
            this.userSetList.on({
                change: function(_set){
                    _set.changingAttributes=_.pick(_set._previousAttributes,_.keys(_set.changed));
                },
                sync: function(_set){
                    _(_set.changingAttributes||{}).chain().keys().each(function(key){ 
                        switch(key){
                            default: 
                                var _old = key.match(/date$/) ? moment.unix(_set.changingAttributes[key]).format("MM/DD/YYYY [at] hh:mmA")
                                             : _set.changingAttributes[key];
                                var _new = key.match(/date$/) ? moment.unix(_set.get(key)).format("MM/DD/YYYY [at] hh:mmA") : _set.get(key);
                                self.eventDispatcher.trigger("add-message",{type: "success", 
                                    short: self.messageTemplate(
                                        {type:"set_saved",opts:{set_id:_set.get("set_id"), user_id: _set.get("user_id")}}),
                                    text: self.messageTemplate({type:"set_saved_details",opts:{setname:_set.get("set_id"),
                                        key: key, user_id: _set.get("user_id"),oldValue: _old, newValue: _new}})});
                            }
                        });
                }
            })

        }

    });
        
	return ProblemSetDetailsView;
});