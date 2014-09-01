/**
 *  This is the ProblemSetDetailView.  The view contains the interface to all of the
 *  details of a given homework set including the changing of HWSet properties and assigning of users. 
 *
 *  One must pass a ProblemSet as a model to this.  
 * 
 **/


define(['backbone','underscore','views/TabbedMainView','views/MainView', 'views/TabView','views/ProblemSetView',
    'models/ProblemList','views/CollectionTableView','models/ProblemSet','models/UserSetList','sidebars/ProblemListOptionsSidebar',
    'config','bootstrap'], 
    function(Backbone, _,TabbedMainView,MainView,TabView,ProblemSetView,ProblemList,CollectionTableView,ProblemSet,
        UserSetList,ProblemListOptionsSidebar, config){
	var ProblemSetDetailsView = TabbedMainView.extend({
        className: "set-detail-view",
        messageTemplate: _.template($("#problem-sets-manager-messages-template").html()),
        initialize: function(options){
            var self = this;

            var opts = _(options).pick("users","settings","eventDispatcher");

            this.views = options.views = {
                propertiesView : new DetailsView(opts),
                problemsView : new ShowProblemsView(_.extend({messageTemplate: this.messageTemplate, parent: this},opts)),
                usersAssignedView : new AssignUsersView(opts),
                customizeUserAssignView : new CustomizeUserAssignView(opts)
            };
            this.views.problemsView.on("page-changed",function(num){
                self.eventDispatcher.trigger("save-state");
            })
            options.tabs = ".set-details-tab";
            options.tabContent = ".set-details-tab-content";
            options.template = $("#HW-detail-template").html();
            TabbedMainView.prototype.initialize.call(this,options);
            this.state.on("change:set_id", function() {
                self.changeProblemSet(self.state.get("set_id"));
            })

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
            TabbedMainView.prototype.render.call(this);            
            this.stickit(this.state,this.bindings);
            if(this.state.get("set_id")){
                this.changeProblemSet(this.state.get("set_id"));
            }
        },
        getHelpTemplate: function () {
            switch(this.state.get("tab_name")){
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
        sidebarEvents: {
            "change-display-mode": function(evt) { 
                if(_.isFunction(this.views[this.state.get("tab_name")].changeDisplayMode)){
                    this.views[this.state.get("tab_name")].changeDisplayMode(evt);
                }},
            "show-hide-tags": function(_show){
                this.views[this.state.get("tab_name")].tabState.set("show_tags",_show);
            },
            "show-hide-path": function(_show){
                this.views[this.state.get("tab_name")].tabState.set("show_path",_show);
            },
            "undo-problem-delete": function(){
                this.views.problemsView.problemSetView.undoDelete();
                this.views.problemsView.problemSetView.updateNumProblems()
                if(this.views.problemsView.problemSetView.undoStack.length==0 && 
                    this.sidebar instanceof ProblemListOptionsSidebar){
                        this.sidebar.$(".undo-delete-button").attr("disabled","disabled");
                }
            }
        },
        changeProblemSet: function (setName)
        {
            var self = this;
            this.state.set("set_id",setName);
        	this.problemSet = this.problemSets.findWhere({set_id: setName});
            _(this.views).chain().keys().each(function(view){
                self.views[view].setProblemSet(self.problemSet);
            });
            this.views.problemsView.currentPage = 0; // make sure that the problems start on a new page. 
            this.loadProblems();
            this.views[this.state.get("tab_name")].render();
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

    var DetailsView = TabView.extend({
        tabName: "Set Details",
        initialize: function (options) {
            var self = this;
            _.bindAll(this,'render','setProblemSet',"showHideReducedScoringDate");
            this.users = options.users;
            this.settings = options.settings;
            TabView.prototype.initialize.apply(this,[options]);
            this.tabState.on("change:show_time",function (val){
                self.showTime(self.tabState.get("show_time"));
                self.stickit();
            });
        },
        render: function(){
            if(this.model){
                this.$el.html($("#set-properties-tab-template").html());
                this.showHideReducedScoringDate();
                this.showTime(this.tabState.get("show_time"));
                this.$(".show-time-toggle").prop("checked",this.tabState.get("show_time"));
                this.stickit();
            }
            return this;
        },
        events: {
            "click .assign-all-users": "assignAllUsers",
            "change .show-time-toggle": function(evt){
                this.tabState.set("show_time",$(evt.target).prop("checked"));
            },
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
        },
        showTime: function(_show){
            if(_show){
                this.$(".open-date,.due-date,.reduced-scoring-date,.answer-date")
                    .addClass("edit-datetime-showtime").removeClass("edit-datetime");
            } else {
                this.$(".open-date,.due-date,.reduced-scoring-date,.answer-date")
                    .removeClass("edit-datetime-showtime").addClass("edit-datetime");
            }
            
        },
        getDefaultState: function () { return {set_id: "", show_time: false};}

    });

    var ShowProblemsView = TabView.extend({
        tabName: "Problems",
        initialize: function (options) {
            var self = this;
            _(this).bindAll("setProblemSet");
            this.parent = options.parent;
            this.problemSetView = new ProblemSetView({settings: options.settings, messageTemplate: options.messageTemplate});
            TabView.prototype.initialize.apply(this,[options]);
            this.tabState.on("change:show_path",function(){
                self.problemSetView.showPath(self.tabState.get("show_path"));
            }).on("change:show_tags",function(){
                self.problemSetView.showTags(self.tabState.get("show_tags"));
            });
        },
        render: function (){
            this.problemSetView.setElement(this.$el);
            this.problemSetView.render();
        },
        setProblemSet: function(_set){
            var self = this;
            this.problemSetView.setProblemSet(_set);
            if(this.problemSetView.problemSet){
                this.problemSetView.problemSet.on("problem-deleted",function(p){
                    self.parent.sidebar.$(".undo-delete-button").removeAttr("disabled");
                })    
            }
            return this;
        },
        set: function(options){
            this.problemSetView.set(_.extend({},options,this.tabState.pick("show_path","show_tags")));
            return this;
        },
        changeDisplayMode: function(evt){
            this.problemSetView.changeDisplayMode(evt);
        },
        getDefaultState: function () {
            return {set_id: "", library_path: "", page_num: 0, rendered: false, page_size: 10, show_path: false, show_tags: false};
        },

    });

var AssignUsersView = Backbone.View.extend({
        tabName: "Assign Users",
        initialize: function (options) {
            this.users = options.users;
            TabView.prototype.initialize.apply(this,[options]);
        },
        render: function() {
            this.$el.html($("#assign-users-template").html());
            this.update();
            return this;
        },
         events: {  
            "click .assign-users-btn": "assignUsers",
            "click .unassign-users-btn": "unassignUsers",
            "click .select-all": "selectAll"
        },
        update: function (){
            var self = this;
            if(typeof(this.problemSet)==="undefined"){
                return;
            }
            var assignedUsers = this.problemSet.get("assigned_users");
            var unassignedUsers = _(this.users.pluck("user_id")).difference(assignedUsers);
            var assignedSelect = this.$(".assigned-user-list").empty();
            var unassignedSelect = this.$(".unassigned-user-list").empty();
            var userTemplate = _.template($("#assigned-user-list-user-template").html());
            _(assignedUsers).each(function(userID){
                assignedSelect.append(userTemplate(self.users.findWhere({user_id: userID}).attributes));
            });
            _(unassignedUsers).each(function(userID){
                unassignedSelect.append(userTemplate(self.users.findWhere({user_id: userID}).attributes));
            });
        },
        setProblemSet: function(_set) {
            var self = this; 
            this.problemSet = _set;
            if(_set){
                this.render();
            }
            return this;
        },
        selectAll: function (){
            this.tabState.set("assigned_users",this.$(".select-all").prop("checked")?
                            this.originalUnassignedUsers: []);
        },
        assignUsers: function(){
            var selectedUnassignedUsers = this.$(".unassigned-user-list").val();
            this.problemSet.set("assigned_users", _(this.problemSet.get("assigned_users")).union(selectedUnassignedUsers));
            this.update();
        },
        unassignUsers: function(){
            var selectedAssignedUsers = this.$(".assigned-user-list").val();
            var conf = confirm("Do you want to unassign the users: " + selectedAssignedUsers.join(", ") + "?" 
                + " All data will be removed and this cannot be undone.");
            if(conf){
                this.problemSet.set("assigned_users",_(this.problemSet.get("assigned_users")).difference(selectedAssignedUsers));
                this.update();                
            }
        },
        getDefaultState: function () {
            return {assigned_users: [], unassigned_users: []};
        }
    });

    var CustomizeUserAssignView = TabView.extend({
        tabName: "Student Overrides",
        initialize: function(options){
            _.bindAll(this,"render","saveChanges","buildCollection","setProblemSet");
            var self = this;
            // this.model is a clone of the parent ProblemSet.  It is used to save properties for multiple students.

            this.model = options.problemSet ? new ProblemSet(options.problemSet.attributes): null;
            _.extend(this,_(options).pick("users","settings","eventDispatcher"));
            TabView.prototype.initialize.apply(this,[options]);
            this.tabState.on({
                "change:filter_string": function(){
                    self.userSetTable.set(self.tabState.pick("filter_string")).updateTable();
                    self.update();
                },
                "change:show_section change:show_recitation change:show_time": function(){
                    self.update();}
                });
        },
        render: function () {
            var self = this;
            if(! this.model){
                return;
            }
            this.tableSetup();
            this.$el.html($("#loading-usersets-template").html());
            if (this.collection.size()>0){
                this.$el.html($("#customize-assignment-template").html());
                (this.userSetTable = new CollectionTableView({columnInfo: this.cols, collection: this.collection, 
                        paginator: {showPaginator: false}, tablename: ".users-table", page_size: -1,
                        row_id_field: "user_id", table_classes: "table table-bordered table-condensed"})).render();
                this.userSetTable.set(this.tabState.pick("selected_rows"))
                    .on({
                        "selected-row-changed": function(rowIDs){
                            self.tabState.set({selected_rows: rowIDs});
                            }, 
                        "table-sorted": function (){
                            self.update();
                            }
                        })
                    .updateTable();
                this.$el.append(this.userSetTable.el);
                this.update();
                this.stickit();
                this.stickit(this.tabState,{
                    ".filter-text": "filter_string",
                    ".show-section": "show_section",
                    ".show-recitation": "show_recitation",
                    ".show-time": "show_time"
                });
            } else {
                this.userSetList.fetch({success: function () {self.buildCollection().render();}});
            }
        },
        events: {
            "click .save-changes": "saveChanges",
            "click .clear-filter-button": function () { 
                this.tabState.set("filter_string", "");
                this.userSetTable.set({filter_string: ""}).updateTable();
                this.update();
            }
        },
        bindings: { "#customize-problem-set-controls .open-date" : "open_date",
                    "#customize-problem-set-controls .due-date": "due_date",
                    "#customize-problem-set-controls .answer-date": "answer_date",
                    "#customize-problem-set-controls .reduced-scoring-date": "reduced_scoring_date",
        },
        saveChanges: function (){
            var self = this;
            _(this.userSetTable.getVisibleSelectedRows()).chain().map(function(_userID) { 
                    return self.userSetList.findWhere({user_id: _userID});
                }).each(function(_model){
                    _model.set(self.model.pick("open_date","due_date","answer_date","reduced_scoring_date"));
                });
        },
        setProblemSet: function(_set) {
            this.problemSet = _set;  // this is the globalSet
            if(_set){
                this.model = new ProblemSet(_set.attributes);  // this is used to pull properties for the userSets.  We don't want to overwrite the properties in this.problemSet
                this.userSetList = new UserSetList([],{problemSet: this.model,type: "users"});
                this.userSetList.on("change:due_date change:answer_date change:reduced_scoring_date change:open_date"
                    , function(model){ model.save();
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
                model.set(self.users.findWhere({user_id: model.get("user_id")}).pick("section","recitation","first_name","last_name"));
            });
            this.collection.on({change: function(model){
                self.userSetList.findWhere({user_id: model.get("user_id")})
                    .set(model.pick("open_date","due_date","answer_date","enable_reduced_scoring")).save();
            }});
            this.setMessages();

            return this;
        },
        update: function () {
            config.changeClass({state: this.tabState.get("show_section"), els: this.$(".section"), remove_class: "hidden"})
            config.changeClass({state: this.tabState.get("show_recitation"), els: this.$(".recitation"), remove_class: "hidden"})
            config.changeClass({state: this.problemSet.get("enable_reduced_scoring") && this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}"),
                els: this.$(".reduced-scoring-date,.reduced-scoring-header"), remove_class: "hidden"});
            config.changeClass({state: this.tabState.get("show_time"), remove_class: "edit-datetime", add_class: "edit-datetime-showtime",
                els: this.$(".open-date,.due-date,.reduced-scoring-date,.answer-date")})
            this.userSetTable.refreshTable();
            this.stickit();
        },
        tableSetup: function () {
            var self = this;
            this.cols = [{name: "Select", key: "_select_row", classname: "select-set"},
                {name: "User ID", key: "user_id", classname: "user-id", show_column: false},
                {name: "First Name", key: "first_name", classname: "first-name", datatype: "string"},
                {name: "Last Name", key: "last_name", classname: "last-name", datatype: "string"},
                {name: "Open Date", key: "open_date", classname: "open-date edit-datetime", 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Reduced Scoring Date", key: "reduced_scoring_date", classname: "reduced-scoring-date edit-datetime", 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Due Date", key: "due_date", classname: "due-date edit-datetime", 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Answer Date", key: "answer_date", classname: "answer-date edit-datetime", 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Section", key: "section", classname: "section", editable: false, datatype: "string"},
                {name: "Recitation", key: "recitation", classname: "recitation", editable: false,datatype: "string"},
                {name: "Enable Reduced Scoring", key: "enable_reduced_scoring", classname: "enable-reduced-scoring",
                    editable: false, datatype: "boolean", show_column: false}
                ];
                
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

        },        
        getDefaultState: function () { return {set_id: "", filter_string: "", show_recitation: false, show_section: false,
                show_time: false, selected_rows: []};}

    });
        
	return ProblemSetDetailsView;
});