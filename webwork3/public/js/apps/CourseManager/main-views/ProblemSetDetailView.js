/**
 *  This is the ProblemSetDetailView.  The view contains the interface to all of the
 *  details of a given homework set including the changing of HWSet properties and assigning of users. 
 *
 *  The ProblemSetDeatilsView is a TabbedMainView and contains the other TabViews (DetailsView, ShowProblemsView,  AssignUsersView, 
 *       CustomizeUsersView). 
 * 
 **/


define(['backbone','underscore','views/TabbedMainView','views/MainView', 'views/TabView',
        'views/ProblemSetView', 'models/ProblemList','views/CollectionTableView','models/ProblemSet',
        'models/UserSetList','sidebars/ProblemListOptionsSidebar','views/AssignmentCalendar',
        'models/ProblemSetList','models/SetHeader','models/Problem',
        'apps/util','config','moment','bootstrap'], 
    function(Backbone, _,TabbedMainView,MainView,TabView,ProblemSetView,ProblemList,CollectionTableView,ProblemSet,
        UserSetList,ProblemListOptionsSidebar, AssignmentCalendar,ProblemSetList,SetHeader,Problem,util,config,moment){
	var ProblemSetDetailsView = TabbedMainView.extend({
        className: "set-detail-view",
        messageTemplate: _.template($("#problem-sets-manager-messages-template").html()),
        initialize: function(options){
            var self = this;

            var opts = _(options).pick("users","settings","eventDispatcher","problemSets");

            this.views = options.views = {
                propertiesView : new DetailsView(opts),
                problemsView : new ShowProblemsView(_.extend({messageTemplate: this.messageTemplate, 
                                                              parent: this},opts)),
                usersAssignedView : new AssignUsersView(opts),
                customizeUserAssignView : new CustomizeUserAssignView(opts),
                setHeaderView: new SetHeadersView(opts)
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
            });
            
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
            },
            "add-prob-from-group": function(group_name) {
                this.problemSet.addProblem(new Problem({source_file: "group:" + group_name}));
            }
        },
        getDefaultState: function () {
            return _.extend({set_id: ""}, TabbedMainView.prototype.getDefaultState.apply(this));   
        },
        changeProblemSet: function (setName)
        {
            var self = this;
            if(_.isUndefined(setName) || setName == ""){
                this.views.propertiesView.setProblemSet();
                return;
            }
            this.state.set("set_id",setName);
        	this.problemSet = this.problemSets.findWhere({set_id: setName});
            _(this.views).chain().keys().each(function(view){
                self.views[view].unstickit();
                if(! _.isUndefined(self.problemSet)){
                    self.views[view].setProblemSet(self.problemSet);
                }
            });
            this.views.problemsView.currentPage = 0; // make sure that the problems start on a new page. 
            this.loadProblems();
            this.views[this.state.get("tab_name")].render();
            return this;
        },
        loadProblems: function () {
            var self = this;
            if(_.isUndefined(this.problemSet)){
                return;
            }
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
                        console.log(_userSet.changed);
                        _userSet.changingAttributes=_.pick(_userSet._previousAttributes,_.keys(_userSet.changed));
                        _userSet.save();
                    },
                    sync: function(_userSet){  // note: this was just copied from ProblemSetsManager.js  perhaps a common place for this
                        _(_userSet.changingAttributes||{}).chain().keys().each(function(key){
                            var _old = key.match(/date$/)
                                        ? moment.unix(_userSet.changingAttributes[key]).format("MM/DD/YYYY [at] hh:mmA")
                                        : _userSet.changingAttributes[key];
                            var _new = key.match(/date$/) 
                                        ? moment.unix(_userSet.get(key)).format("MM/DD/YYYY [at] hh:mmA") 
                                        : _userSet.get(key);
                            self.eventDispatcher.trigger("add-message",{type: "success", 
                                short: self.messageTemplate({type:"set_saved",opts:{setname:_userSet.get("set_id")}}),
                                text: self.messageTemplate({type:"set_saved_details",
                                                            opts:{setname:_userSet.get("set_id"),key: key,
                                                            oldValue: _old, newValue: _new}})});
                            _set.changingAttributes = _(_set.changingAttributes).omit(key);
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
            _.bindAll(this,'render','setProblemSet',"showHideReducedScoringDate","showHideGateway");
            _(this).extend(_(options).pick("users","settings","problemSets"));
            TabView.prototype.initialize.apply(this,[options]);
            this.model = this.problemSets.findWhere({set_id: this.tabState.get("set_id")});
            this.tabState.on("change:show_time",function (val){
                self.showTime(self.tabState.get("show_time"));
                if(self.model){
                    self.stickit();
                }
                // gets rid of the line break for showing the time in this view. 
                self.$('span.time-span').children('br').attr("hidden",true)    
            }).on("change:show_calendar",function(){
               self.showCalendar(self.tabState.get("show_calendar"));
            })
             // this sets up a problem set list containing only the current ProblemSet and builds a calendar.
            this.calendarProblemSets = new ProblemSetList([],{dateSettings: util.pluckDateSettings(this.settings)});
            this.calendar = new AssignmentCalendar({users: this.users,settings: this.settings,
                                                problemSets: this.calendarProblemSets});
            this.calendar.on("calendar-change",function() {
                self.tabState.set({first_day: self.calendar.state.get("first_day")}); 
                self.showHideReducedScoringDate();
            })
        },
        render: function(){
            if(this.model){
                if(this.model.get("assignment_type") == "jitar"){
                    this.$el.html($("#assign-type-not-supported").html());
                    return;
                }
                this.$el.html($("#set-properties-tab-template").html());
                this.showTime(this.tabState.get("show_time"));
                this.showCalendar(this.tabState.get("show_calendar"));
                this.showHideGateway();
                util.changeClass({state: this.tabState.get("show_calendar"), add_class: "hidden",els: this.$(".hideable")});
                util.changeClass({state: this.tabState.get("show_calendar"), remove_class: "hidden", els: this.$(".calendar-row")});

                this.showHideReducedScoringDate();
                this.stickit();
                // gets rid of the line break for showing the time in this view. 
                $('span.time-span').children('br').attr("hidden",true)    
                this.model.on("change:assignment_type",this.showHideGateway);
            } else {
                this.$el.html("");   
            }

            return this;
        },
        events: {
            "click .assign-all-users": "assignAllUsers",
            "click .show-time-toggle": function(evt){
                this.tabState.set("show_time",!this.tabState.get("show_time"));
            },
            "click .show-calendar-toggle": function(evt){
                this.tabState.set("show_calendar",!this.tabState.get("show_calendar"));
            },
            "keyup .input-blur": function(evt){ 
                if(evt.keyCode == 13) { $(evt.target).blur()}
            },
        },
        assignAllUsers: function(){
            this.model.set({assigned_users: this.users.pluck("user_id")});
        },
        setProblemSet: function(_set) {
            if(_.isUndefined(_set)){
                this.model = undefined;
                return;
            }
            var self = this; 
            this.model = _set;
            this.tabState.set("set_id",this.model.get("set_id"));
            if(this.model){
                this.model.on("change:enable_reduced_scoring",this.render);
            }
            this.model.on("sync",function(){  // pstaab: can we integrate this into the stickit handler code in config.js ? 
                // gets rid of the line break for showing the time in this view. 
                self.$('span.time-span').children('br').attr("hidden",true);
                _.delay(self.showHideReducedScoringDate,100); // hack to get reduced scoring to be hidden. 
            });
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
            ".hide-hint": "hide_hint",
            ".num-problems": { observe: "problems", onGet:function(value,options) {
                return value.length;  
            }},
            "#set-type": {observe: "assignment_type", selectOptions: { 
                collection: [{label: "Homework", value: "default"},
                             {label: "Gateway/Quiz",value: "gateway"},
                             {label: "Proctored Gateway/Quiz", value: "proctored_gateway"}]}},
            ".users-assigned": {
                observe: "assigned_users",
                onGet: function(value, options){ return value.length + "/" +this.users.size();}
            },
            ".version-time-limit": "version_time_limit",
            ".time-limit-cap": "time_limit_cap",
            ".attempts-per-version": "attempts_per_version",
            ".time-interval": "time_interval",
            ".version-per-interval": "version_per_interval",
            ".problem-random-order": "problem_randorder",
            ".problems-per-page": "problems_per_page",
            ".pg-password": "pg_password",
            // I18N
            ".hide-score": {observe: ["hide_score","hide_score_by_problem"], selectOptions: {
                collection: [{label: "Yes", value: "N:"},{label: "No", value: "Y:N"},
                        {label: "Only After Set Answer Date", value: "BeforeAnswerDate:N"},
                        {label: "Totals only (not problem scores)", value: "Y:Y"},
                        {label: "Totals only, only after answer date", value: "BeforeAnswerDate:Y"}]},
                           onGet: function(values){ return values.join(":"); },
                           onSet: function(val) { return val.split(":");}
                           },
            ".hide-work": {observe: "hide_work", selectOptions: { 
                // are these labels correct?  
                collection: [{label:"Yes",value: "N"},{label: "No", value: "Y"},
                                {label: "Only After Set Answer Date", value: "BeforeAnswerDate"}]}}
        },
        showHideGateway: function () {
            var type = this.model.get("assignment_type");
            util.changeClass({state: type =="gateway" || type == "proctored_gateway",
                                     els: this.$(".gateway-row"),remove_class: "hidden"});
            util.changeClass({state: type=="gateway" || type == "default",
                                     els: this.$(".pg-row"),add_class:"hidden"});                  
        },
        showHideReducedScoringDate: function(){
            if(typeof(this.model)==="undefined"){ return;}
            util.changeClass({state: this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}"),
                                remove_class: "hidden", 
                                els: this.$(".reduced-scoring-date,.reduced-scoring").closest("tr")});
            util.changeClass({ state: this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}") &&  
                    this.model.get("enable_reduced_scoring"), els: this.$(".reduced-scoring-date").closest("tr"), 
                              remove_class: "hidden"});
            if(this.tabState.get("show_calendar")){
                util.changeClass({state: true, els: this.$(".reduced-scoring-date").closest("tr"), 
                              add_class: "hidden"});
                util.changeClass({state: this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}") &&  
                    this.model.get("enable_reduced_scoring"), els: this.$(".assign-reduced-scoring"),
                                  remove_class: "hidden"});
            }

            if(this.model.get("enable_reduced_scoring")){
                // fill in a reduced_scoring_date if the field is empty or 0. 
                // I think this should go into the ProblemSet model upon either parsing or creation. 
                if(this.model.get("reduced_scoring_date")=="" || this.model.get("reduced_scoring_date")==0){
                    var rcDate = moment.unix(this.model.get("due_date"))
                        .subtract(this.settings.getSettingValue("pg{ansEvalDefaults}{reducedScoringPeriod}"),"minutes");
                    this.model.set({reduced_scoring_date: rcDate.unix()});
                }
            } 
        },
        showTime: function(_show){
            this.tabState.set("show_time",_show);
            // hide or show the date rows in the table
            util.changeClass({state: _show, remove_class: "edit-datetime", add_class: "edit-datetime-showtime",
                                els: this.$(".open-date,.due-date,.reduced-scoring-date,.answer-date")});
            // change the button text
            this.$(".show-time-toggle").button(_show?"hide":"reset");
            
        },
        showCalendar: function(_show){
            var self = this;
            this.tabState.set("show_calendar",_show);
            // change the button text
            this.$(".show-calendar-toggle").button(_show?"hide":"reset");
            util.changeClass({state: this.tabState.get("show_calendar"), add_class: "hidden",els: this.$(".hideable")});
            util.changeClass({state: this.tabState.get("show_calendar"), remove_class: "hidden", els: this.$(".calendar-row")});
            this.showHideReducedScoringDate();
            if(! _show) return;
            if(typeof(this.model)==="undefined") return;
            this.calendarProblemSets.reset(this.problemSets.where({set_id: this.model.get("set_id")}));
            var assignmentDateList = util.buildAssignmentDates(this.calendarProblemSets);
            var first_day = this.tabState.get("first_day");
            if(! moment(this.tabState.get("first_day")).isValid()){
                var open_date = moment.unix(this.model.get("open_date"))
                first_day = open_date.subtract(open_date.day(),"days");
            }
            this.calendar.set({assignmentDates: assignmentDateList,first_day: first_day})
                .setElement(this.$(".calendar-cell")).render();
            this.problemSets.on("change",function(m){
                self.calendarProblemSets.findWhere({set_id: m.get("set_id")}).set(m.changed);
                self.calendar.render();
            });
            
        },
        getDefaultState: function () { return {set_id: "", show_time: false, show_calendar: false, first_day: ""};}

    });
    
    var SetHeadersView = TabView.extend({
        tabName: "Set Headers",
        initialize: function(opts){
            TabView.prototype.initialize.apply(this,[opts]);
            this.headerFiles = void 0;
            this.setHeader = void 0;
            
        },
        render: function(){
            var self = this; 
            var tmpl = _.template($("#set-headers-template").html());
            if(this.model && this.model.get("assignment_type") == "jitar"){
                    this.$el.html($("#assign-type-not-supported").html());
                    return this;
            }
            this.$el.html(tmpl(this.tabState.attributes));  
            if(this.headerFiles && this.setHeader){
                this.showSetHeaders();
                this.stickit();
            } else if (_.isUndefined(this.headerFiles)){
                $.get(config.urlPrefix +  "courses/" + config.courseSettings.course_id + "/headers", function( data ) {
                    self.headerFiles = _(data).map(function(f){ return {label: f, value: f};});
                    self.headerFiles.unshift({label: "Use Default Header File", value: "defaultHeader"});  // I18N
                    self.render();
                });
            } else if(_.isUndefined(this.setHeader)) {

                this.setHeader = new SetHeader({set_id: this.model.get("set_id")});
                this.setHeader.on("change", function(model){
                    model.save(model.changed,{success: function () { self.showSetHeaders();}});
                    self.showSetHeaders();
                }).on("change:set_header_content", function(){
                    self.editing = "setheader";   
                }).on("change:hardcopy_header_content",function(){
                    self.editing = "hardcopyheader";   
                }).on("sync",function(){
                    switch(self.editing){
                        case "setheader":
                            $("#view-header-button").parent().button("toggle"); break;
                        case "hardcopyheader":
                            $("#view-hardcopy-button").parent().button("toggle"); break;
                    }
                    self.editing = "";
                }).fetch({success: function (){
                    self.render();
                }});
                
            }
        },
        showSetHeaders: function (){
            var output = "";
            this.$("#hardcopy-header,#set-header").parent().removeClass("has-error");
            switch($(".view-options input:checked").attr("id")){
                case "view-header-button": 
                    output = this.setHeader.get("set_header_html");
                    this.$(".header-output").addClass("rounded-border");
                    break;   
                case "view-hardcopy-button": 
                    output = this.setHeader.get("hardcopy_header_html");
                    this.$(".header-output").addClass("rounded-border");
                    break; 
                case "edit-header-button":
                    if(this.setHeader.get("set_header") == "defaultHeader") {
                        // I18N
                        output = "Please select a header file to edit"; 
                        this.$("#set-header").parent().addClass("has-error");
                    } else {
                        output = $("#edit-header-template").html()
                    }
                    
                    break;
                case "edit-hardcopy-button":
                    if(this.setHeader.get("hardcopy_header") == "defaultHeader") {
                        // I18N
                        output = "Please select a header file to edit"; 
                        this.$("#hardcopy-header").parent().addClass("has-error");
                    } else {
                        output = $("#edit-hardcopy-template").html()
                    }
                    
                    break;
            }
            this.$(".header-output").html(output);
            this.stickit(this.setHeader,this.headerBindings);
        },
        events: {
            "change .view-options input": function () { 
                this.showSetHeaders();
            }  
        },
        bindings: {
            '#set-description': {observe: 'description', events: ['blur']},
            '#set-header': { observe: "set_header", selectOptions: {collection: 'this.headerFiles'}},
            '#hardcopy-header': { observe: "hardcopy_header", selectOptions: {collection: 'this.headerFiles'}},
            
        },
        headerBindings: {
            '#edit-header-textarea': {observe: "set_header_content", events: ['blur']},
            '#edit-hardcopy-textarea': {observe: "hardcopy_header_content", events: ['blur']},
        },
        setProblemSet: function(_set){
            var self = this; 
            this.tabState.set({set_id: _set.get("set_id")});
            this.model = _set;
            this.model.on("change:set_header change:hardcopy_header",function (model) {
                if(self.setHeader){
                    self.setHeader.set(model.changed);
                }
            });
            return this;
        },
        getDefaultState: function () {
            return {set_id: ""};   
        }
        
    });

    var ShowProblemsView = TabView.extend({
        tabName: "Problems",
        initialize: function (options) {
            var self = this;
            _(this).bindAll("setProblemSet");
            this.parent = options.parent;
            this.problemSetView 
                = new ProblemSetView(_(options).pick("settings","messageTemplate","eventDispatcher"));
            TabView.prototype.initialize.apply(this,[options]);
            this.tabState.on("change:show_path",function(){
                self.problemSetView.showPath(self.tabState.get("show_path"));
            }).on("change:show_tags",function(){
                self.problemSetView.showTags(self.tabState.get("show_tags"));
            });
        },
        render: function (){
            var self = this;
            if(this.problemSetView.problemSet && this.problemSetView.problemSet.get("assignment_type") == "jitar"){
                    this.$el.html($("#assign-type-not-supported").html());
                    return;
                }
            
            this.problemSetView.setElement(this.$el);
            this.problemSetView.render();
            // disable the ability to drag problems when the set is open. 
            
            this.problemSetView.on("rendered",function(){
                util.changeClass({els: $(".reorder-handle"), state: self.problemSetView.problemSet.isOpen(),
                                add_class:"disabled",remove_class:""})  
            });
        },
        setProblemSet: function(_set){
            this.problemSetView.setProblemSet(_set);
            return this;
        },
        // set a parameter. 
        set: function(options){
            this.problemSetView.set(_.extend({},options,this.tabState.pick("show_path","show_tags")));
            return this;
        },
        changeDisplayMode: function(evt){
            this.problemSetView.changeDisplayMode(evt);
        },
        getDefaultState: function () {
            return {set_id: "", library_path: "", page_num: 0, rendered: false, page_size: 10, 
                    show_path: false, show_tags: false};
        },

    });

var AssignUsersView = Backbone.View.extend({
        tabName: "Assign Users",
        initialize: function (options) {
            this.users = options.users;
            TabView.prototype.initialize.apply(this,[options]);
        },
        render: function() {
            if(this.problemSet && this.problemSet.get("assignment_type") == "jitar"){
                    this.$el.html($("#assign-type-not-supported").html());
                    return;
            }
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
            _.bindAll(this,"render","saveChanges","buildCollection","setProblemSet","update");
            var self = this;
            // this.model is a clone of the parent ProblemSet.  It is used to save properties for multiple students.

            this.model = options.problemSet ? new ProblemSet(options.problemSet.attributes): null;
            
            if(options.problemSet){
                options.problemSet.on("change",function(_model){
                    self.model.set(_model.changed); 
                });
            }
            
            _.extend(this,_(options).pick("users","settings","eventDispatcher"));
            TabView.prototype.initialize.apply(this,[options]);
            this.tabState.on("change:filter_string", function(){
                    self.userSetTable.set(self.tabState.pick("filter_string")).updateTable();
                    self.update();
            }).on("change:show_section change:show_recitation change:show_time", this.update);
        },
        render: function () {
            var self = this;
            if(! this.model){
                return;
            }
            if(this.problemSet && this.problemSet.get("assignment_type") == "jitar"){
                    this.$el.html($("#assign-type-not-supported").html());
                    return;
            }
            this.tableSetup();
            this.$el.html($("#loading-usersets-template").html());
            if (this.collection.size()>0){
                this.$el.html($("#customize-assignment-template").html());
                (this.userSetTable = new CollectionTableView({columnInfo: this.cols, 
                                            collection: this.collection, 
                                            paginator: {showPaginator: false}, 
                                            tablename: ".users-table", page_size: -1,
                                            row_id_field: "user_id", 
                                            table_classes: "table table-bordered table-condensed"}));
                // The following is needed to make sure that the reduced-scoring date shows up in the student overrides table. 
                this.userSetTable.collection.each(function(model) { model.show_reduced_scoring = true;}); 
                this.userSetTable.render();
                this.userSetTable.set(this.tabState.pick("selected_rows"))
                    .on("selected-row-changed", function(rowIDs){
                            self.tabState.set({selected_rows: rowIDs});
                    }).on("table-sorted table-changed",this.update).updateTable();
                
                this.$el.append(this.userSetTable.el);
                this.update();
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
            var self = this;
            this.problemSet = _set;  // this is the globalSet
            if(_set){
                // this is used to pull properties for the userSets.  We don't want to overwrite the properties in this.problemSet
                this.model = new ProblemSet(_set.attributes);  
                this.model.show_reduced_scoring = true; 
                this.userSetList = new UserSetList([],{problemSet: this.model,type: "users"});
                this.userSetList.on("change:due_date change:answer_date change:reduced_scoring_date "
                                    + "change:open_date", function(model){ 
                            model.adjustDates(); 
                            model.save();
                });
            }
            if(this.problemSet){
                this.problemSet.on("change",function(_m){
                    self.collection = new Backbone.Collection(); // reset the collection so data is refetched.
                }).on("change",function(_model){
                    self.model.set(_model.changed); 
                });
            }
            
            // make a new collection that merges the UserSetListOfUsers and the userList 
            this.collection = new Backbone.Collection();
            return this;
        }, 
        buildCollection: function(){ // since the collection needs to contain a mixture of userSet and user properties, we merge them. 
            var self = this;
            this.collection.reset(this.userSetList.models);
            //this.collection is a collection of models based on user sets.  The following will also pick information
            // from the users that is useful for this view. 
            this.collection.each(function(model){
                model.set(self.users.findWhere({user_id: model.get("user_id")})
                          .pick("section","recitation","first_name","last_name"),{silent: true});  
            });
            this.collection.on({change: function(model){
                self.userSetList.findWhere({user_id: model.get("user_id")})
                    .set(model.pick("open_date","due_date","answer_date","reduced_scoring_date")).save();
            }});
            this.setMessages();

            return this;
        },
        update: function () {
            if(typeof(this.problemSet) === "undefined"){
                return;
            }
            
            util.changeClass({state: this.tabState.get("show_section"), els: this.$(".section"), remove_class: "hidden"})
            util.changeClass({state: this.tabState.get("show_recitation"), els: this.$(".recitation"), remove_class: "hidden"})
            util.changeClass({state: this.problemSet.get("enable_reduced_scoring") 
                              && this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}"),
                els: this.$(".reduced-scoring-date,.reduced-scoring-header"), remove_class: "hidden"});
            util.changeClass({state: this.tabState.get("show_time"), remove_class: "edit-datetime", add_class: "edit-datetime-showtime",
                els: this.$(".open-date,.due-date,.reduced-scoring-date,.answer-date")})
            if(this.userSetTable && this.model){
                this.userSetTable.refreshTable();
                this.stickit();
            } else {
                this.render();
                return; 
            }
            // color the changed dates blue
            _([".open-date",".due-date",".reduced-scoring-date",".answer-date"]).each(function(date){
                var val = $("#customize-problem-set-controls " + date + " .wwdate").val()
                $(date +" .wwdate").filter(function(i,v) {return $(v).val()!=val;}).css("color","blue");
            });
            var h = $(window).height()-($(".navbar-fixed-top").outerHeight(true) 
                                        + $(".header-set-name").outerHeight(true)
                                        + $("#customize-problem-set-controls").parent().outerHeight()
                                        + $("#footer").outerHeight());
            $("#student-override-container").height(h);

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
                {name: "Enab RS", key: "enable_reduced_scoring", classname: "enable_reduced_scoring", editable: false, 
                        datatype: "boolean", show_column: false}
                ];
                
        },
        messageTemplate: _.template($("#problem-set-messages").html()),
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
                                _set.changingAttributes = _(_set.changingAttributes).omit(key);
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