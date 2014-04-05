/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
define(['module','backbone', 'underscore','models/UserList','models/ProblemSetList','models/SettingList',  
    'views/MainViewList',
    'models/AssignmentDate','models/AssignmentDateList','views/WebPage','config','jquery-ui','bootstrap'
    ], 
function(module, Backbone, _, UserList, ProblemSetList, SettingList,MainViewList,
    AssignmentDate,AssignmentDateList,WebPage,config,ProblemSetListView,UserListView,LibraryOptionsView,
    HelpSidePane,ProblemListOptionsSidePane){
var CourseManager = WebPage.extend({
    tagName: "div",
    initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','updateCalendar','setProblemSetUI', 'setMessages',"showProblemSetDetails",
            "changeView","changeSidebar","loadData","checkData");  // include all functions that need the this object
	    var self = this;

        this.render();
        this.eventDispatcher = _.clone(Backbone.Events);
        this.session = (module.config().session)? module.config().session : {};
        this.settings = (module.config().settings)? new SettingList(module.config().settings, {parse: true}) : null;
        this.users = (module.config().users) ? new UserList(module.config().users) : null;
        this.problemSets = (module.config().sets) ? new ProblemSetList(module.config().sets,{parse: true}) : null;

        _.extend(config.courseSettings,{course_id: module.config().course_id,user: this.session.user});
        if(this.session.user){
            this.startManager();
        } else {
            this.requestLogin({success: this.loadData});
        }

    },
    loadData: function (data) {
        var self = this;
        if(data.logged_in===1){ // logged in successful,  load the data
            this.loginPane.$(".message-bottom").html(config.msgTemplate({type: "loading_data"}))
                .append("<i class='fa fa-spinner fa-spin'></i>");
            this.data_loaded = {settings: false, users: false, problemSets: false};
            // request the session information
            // make the session a Model to save/fetch
            $.get(config.urlPrefix+"courses/"+config.courseSettings.course_id+"/session",function(data){
                self.session = data;
                config.courseSettings.user = self.session.user;
            })
            this.problemSets.fetch({success: function(){self.checkData("problemSets")}});
            this.settings.fetch({success: function(){self.checkData("settings")}});
            this.users.fetch({success: function(){self.checkData("users")}});

            
        } else { // send an error
            this.loginPane.$(".message").html(config.msgTemplate({type: "bad_password"}));
        }
    },
    // wait for all of the data to get loaded in, close the login window, then start the Course Manager. 
    checkData: function(name) {
        this.data_loaded[name] = true;
        console.log(_(this.data_loaded).chain().values().every(_.identity).value());
        if(_(this.data_loaded).chain().values().every(_.identity).value()){
            this.closeLogin();
            this.startManager();
        }
    },
    startManager: function () {
        var self = this;
        this.navigationBar.setLoginName("Welcome " +this.session.user);
        this.buildAssignmentDates();
        this.mainViewList = new MainViewList({settings: this.settings, users: this.users, 
                problemSets: this.problemSets, eventDispatcher: this.eventDispatcher});

        // Build the menu.  Should we make a View for this?  

        var menuItemTemplate = _.template($("#main-menu-item-template").html());
        var ul = $("#menu-navbar-collapse .manager-menu");
        _(this.mainViewList.viewInfo.main_views).each(function(item){
            ul.append(menuItemTemplate({name: item.name}));
        })

        // can't we just pull this from the settings when needed.  Why do we need another variable. 
        config.timezone = this.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    
        // Define all of the views that are visible with the Pulldown menu

        // This information should be in a configuration file
        // then modules could add to it easily 
        // Here, all of the views can be loaded in. 

/*
        this.views = {
            calendar : new AssignmentCalendar({assignmentDates: this.assignmentDateList,
                    viewType: "instructor", calendarType: "month", users: this.users,
                    reducedScoringMinutes: config.settings.getSettingValue("pg{ansEvalDefaults}{reducedScoringPeriod}")}),
            setDetails:  new ProblemSetDetailView({ users: this.users, problemSets: this.problemSets, 
                    eventDispatcher: this.eventDispatcher}),
            allSets:  new ProblemSetsManager({problemSets: this.problemSets, users: this.users}),
            importExport:  new ImportExportView({problemSets: this.problemSets}),
            libraryBrowser : new LibraryBrowser({errorPane: this.errorPane, problemSets: this.problemSets}),
            settings      :  new SettingsView(),
            classlist: new ClasslistView({users: this.users, problemSets: this.problemSets}),
            studentProgress: new StudentProgressView({users: this.users, problemSets: this.problemSets})
        }; */

        _(this.views).chain().keys().each(function(key){ self.views[key].setParentView(self)});

        //this.views.calendar.dispatcher.on("calendar-change", self.updateCalendar);

        this.mainViewList.getViewByName("Calendar")
            .set({assignmentDates: this.assignmentDateList, viewType: "instructor", calendarType: "month"})
            .dispatcher.on("calendar-change",self.updateCalendar);

        // Define all of the option views available for the right side
        // 
        // Again, this should be in a configuration file. 

        // Build the options menu.  Should we make a View for this?  

        var menuItemTemplate = _.template($("#main-menu-item-template").html());
        var ul = $("#menu-navbar-collapse .option-menu");
        _(this.mainViewList.viewInfo.sidepanes).each(function(item){
            ul.append(menuItemTemplate({name: item.name}));
        })

/*        this.sidePane = {
            problemSets: new ProblemSetListView({problemSets: this.problemSets, users: this.users}),
            userList: new UserListView({users: this.users}),
            libraryOptions: new LibraryOptionsView({problemSets: this.problemSets,settings: this.settings}),
            problemList: new ProblemListOptionsSidePane({problemSets: this.problemSets, settings: this.settings}),
            helpSidepane: new HelpSidePane()
        } */


        this.setMessages();  

        // this will automatically save (sync) any change made to a problem set.
        this.problemSets.on("change",function(_set){
            _set.save();
        })        

        // load the previous state of the app
        var state = this.loadState();

        if(state){
            this.changeView(state.view,state);
        } else {
            this.changeView("Calendar",{});    
        }

        // set the initial view to be the Calendar. 
        

        this.navigationBar.on({"change-view": this.changeView,
            "open-option": this.changeSidebar
        });

        this.users.on({"act_as_user": function(model){
            self.session.effectiveUser = model.get("user_id");
            $.ajax({method: "POST", 
                url: config.urlPrefix+"courses/"+config.courseSettings.course_id+"/session", 
                data: {effectiveUser: self.session.effectiveUser},
                success: function () {
                    self.navigationBar.setLoginName("Welcome " +self.session.user + " (" + self.session.effectiveUser + ")");                    
                }
            });
        }});

        $(window).on("beforeunload", function () {
            return config.msgTemplate({type: "leave_page"});
         });

        // Add a link to WW2 via the main menu.

        this.navigationBar.$(".manager-menu").append("<li><a href='/webwork2/"+config.courseSettings.course_id+"''>WeBWorK2</a></li>");

        //$(".ww2-link").attr("href","/webwork2/"+config.courseSettings.course_id); // create a link back to ww2. 

    },

    // can a lot of this be handled by the individual views?  

    setMessages: function (){
        var self = this; 

        this.eventDispatcher.on("save-state",function(state){
            self.saveState(state);
        })

        /* The following is how messages will be handled */

        this.eventDispatcher.on("add-message",function(message){
            self.messagePane.addMessage(message);
        });

        /* Set up all of the events on the problemSets */

        this.problemSets.on("add", function (_set){
            _set.save();
            _set.changingAttributes={add: ""};
        }).on("remove", function(_set){
            _set.destroy({success: function() {
                self.messagePane.addMessage({type:"success",
                    short: config.msgTemplate({type:"set_removed",opts:{setname: _set.get("set_id")}}),
                    text: config.msgTemplate({type: "set_removed_details",opts:{setname: _set.get("set_id")}})});
                       
               // update the assignmentDateList to delete the proper assignments

                self.assignmentDateList.remove(self.assignmentDateList.filter(function(assign) { 
                    return assign.get("problemSet").get("set_id")===_set.get("set_id");}));

            }});
        }).on("change:due_date change:open_date change:answer_date",function(_set){
            var assignments = self.assignmentDateList.filter(function(assign) { 
                    return assign.get("problemSet").get("set_id")===_set.get("set_id");});
            _(assignments).each(function(assign){
                assign.set("date",moment.unix(assign.get("problemSet").get(assign.get("type")+"_date")).format("YYYY-MM-DD"));
            });
        }).on("change",function(_set){
           _set.changingAttributes=_.pick(_set._previousAttributes,_.keys(_set.changed));
        }).on("change:problems",function(_set){
            _set.save();
        }).on("user_sets_added",function(_userSetList){
            _userSetList.on("change",function(_userSet){
                _userSet.changingAttributes=_.pick(_userSet._previousAttributes,_.keys(_userSet.changed));
                _userSet.save();
            }).on("sync",function(_userSet){  // note: this was just copied from HomeworkManager.js  perhaps a common place for this
                _(_.keys(_userSet.changingAttributes||{})).each(function(key){
                    var _old = key.match(/date$/) ? moment.unix(_userSet.changingAttributes[key]).format("MM/DD/YYYY [at] hh:mmA")
                                         : _userSet.changingAttributes[key];
                    var _new = key.match(/date$/) ? moment.unix(_userSet.get(key)).format("MM/DD/YYYY [at] hh:mmA") : _userSet.get(key);
                    self.messagePane.addMessage({type: "success", 
                        short: config.msgTemplate({type:"set_saved",opts:{setname:_userSet.get("set_id")}}),
                        text: config.msgTemplate({type:"set_saved_details",opts:{setname:_userSet.get("set_id"),key: key,
                            oldValue: _old, newValue: _new}})});
                });
            }); // close _userSetList.on 
        }).on("sync", function (_set){
            _(_.keys(_set.changingAttributes||{})).each(function(key){
                switch(key){
                    case "problems":
                        self.messagePane.addMessage({type: "success", 
                            short: config.msgTemplate({type:"set_added",opts:{setname: _set.get("set_id")}}),
                            text: attr.msg});
                        break;
                    case "problem_added": 
                        self.messagePane.addMessage({type: "success", 
                            short: config.msgTemplate({type:"problem_added",opts:{setname: _set.get("set_id")}}),
                            text: config.msgTemplate({type:"problem_added_details",opts:{setname: _set.get("set_id")}})});
                        break;
                    case "problems_reordered": 
                        self.messagePane.addMessage({type: "success", 
                            short: config.msgTemplate({type:"problems_reordered",opts:{setname: _set.get("set_id")}}),
                            text: config.msgTemplate({type:"problems_reordered_details",opts:{setname: _set.get("set_id")}})});
                        break;
                    case "problem_deleted": 
                        self.messagePane.addMessage({type: "success", 
                            short: config.msgTemplate({type:"problem_deleted",opts:{setname: _set.get("set_id")}}),
                            text: config.msgTemplate({type: "problem_deleted_details", opts: _set.changingAttributes[key]})});
                        break;
                    case "assigned_users":
                        self.messagePane.addMessage({type: "success",
                            short: config.msgTemplate({type:"set_saved",opts:{setname:_set.get("set_id")}}), 
                            text: config.msgTemplate({type:"set_assigned_users_saved",opts:{setname:_set.get("set_id")}})}); 
                        break;
                    case "add":
                        self.messagePane.addMessage({type: "success", 
                            short: config.msgTemplate({type:"set_added",opts:{setname: _set.get("set_id")}}),
                            text: config.msgTemplate({type: "set_added_details",opts:{setname: _set.get("set_id")}})});
                        self.assignmentDateList.add(new AssignmentDate({type: "open", problemSet: _set,
                            date: moment.unix(_set.get("open_date")).format("YYYY-MM-DD")}));
                        self.assignmentDateList.add(new AssignmentDate({type: "due", problemSet: _set,
                            date: moment.unix(_set.get("due_date")).format("YYYY-MM-DD")}));
                        self.assignmentDateList.add(new AssignmentDate({type: "answer", problemSet: _set,
                            date: moment.unix(_set.get("answer_date")).format("YYYY-MM-DD")}));

                        break;    
                    default:
                        var _old = key.match(/date$/) ? moment.unix(_set.changingAttributes[key]).format("MM/DD/YYYY [at] hh:mmA")
                                     : _set.changingAttributes[key];
                        var _new = key.match(/date$/) ? moment.unix(_set.get(key)).format("MM/DD/YYYY [at] hh:mmA") : _set.get(key);
                        self.messagePane.addMessage({type: "success", 
                            short: config.msgTemplate({type:"set_saved",opts:{setname:_set.get("set_id")}}),
                            text: config.msgTemplate({type:"set_saved_details",opts:{setname:_set.get("set_id"),key: key,
                                oldValue: _old, newValue: _new}})});
                }
            });
            self.updateCalendar();
        }).on("show",function(_set){   // this will show the given Problem Set sent from "Manage Problem Sets (HWDetailView) or ProblemSetListView"
            self.showProblemSetDetails(_set.get("set_id"));
        }).on("show-help",function(){ // this isn't a particular good way to do this, but is a fix. 
            self.changeSidebar("Help");
        })

        /* This sets the events for the problems (of type ProblemList) in each problem Set */

        this.problemSets.each(function(_set) {
            _set.problems.on("change:value",function(prob){
                // not sure this is actually working.
                prob.changingAttributes={"value_changed": {oldValue: prob._previousAttributes.value, 
                        newValue: prob.get("value"), name: _set.get("set_id"), problem_id: prob.get("problem_id")}}
            }).on("add",function(problems){
                _set.changingAttributes={"problem_added": ""};
            }).on("sync",function(problems){
                _(_.keys(problems.changingAttributes)).each(function(key){
                    switch(key){
                        case "value_changed": 
                            self.messagePane.addMessage({type: "success", 
                                short: config.msgTemplate({type:"set_saved",opts:{setname: _set.get("set_id")}}),
                                text: config.msgTemplate({type: "problems_values_details", opts: problems.changingAttributes[key]})});
                            break;
                        
                    }
                });
            })
        });


        // this handles the validation of the problem sets, mainly validating the dates.  



        this.problemSets.bind('validated:invalid', function(model, errors) {
            var uniqueErrors = _.unique(_.values(errors));
            _(uniqueErrors).each(function(error){
                self.messagePane.addMessage({type: "danger", text: error,
                        short: config.msgTemplate({type:"set_error",opts:{setname: model.get("set_id")}})});

            }); 
        });

        /* Set the events for the settings */

        this.settings.on("change",function(setting){
            setting.changingAttributes=_.pick(setting._previousAttributes,_.keys(setting.changed));
        }).on("sync",function(setting){
            _(_.keys(setting.changingAttributes)).each(function(key){
                    self.messagePane.addMessage({type: "success",
                        short: config.msgTemplate({type:"setting_saved",opts:{varname:setting.get("var")}}), 
                        text: config.msgTemplate({type:"setting_saved_details"
                                ,opts:{varname:setting.get("var"), oldValue: setting.changingAttributes[key],
                                    newValue: setting.get("value") }})}); 
            });
        });


    },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
    },
    showProblemSetDetails: function(setName){
        if (this.objectDragging) return;
        this.changeView("Problem Set Details",{});
        this.currentView.changeHWSet(setName); 
    },
    changeSidebar: function(_name){
        if(this.currentSidePane){
            this.currentSidePane.remove();
        }
        if(_name===""){
            $("#sidebar-container").addClass("hidden");
            $("#main-view").removeClass("col-md-9").addClass("col-md-12");
            return;
        } else {
            $("#sidebar-container").removeClass("hidden");
            $("#main-view").removeClass("col-md-12").addClass("col-md-9");
        }
        $("#sidebar-container").html("<div class='sidebar'></div>");

        (this.currentSidePane = this.mainViewList.getSidepaneByName(_name))
            .setMainView(this.currentView).setElement(this.$(".sidebar")).render();
        this.currentView.setSidePane(this.currentSidePane);

    },
    changeView: function (_name,state){
        if(this.currentView){
            this.currentView.remove();
        }
        $("#main-view").html("<div class='main'></div>");
        this.navigationBar.setPaneName(_name);
        (this.currentView = this.mainViewList.getViewByName(_name)).setElement(this.$(".main"))
            .setState(state).render();

        this.changeSidebar(_(this.mainViewList.viewInfo.main_views).findWhere({name: _name}).default_sidepane);
        this.saveState();
        //this.updateProblemSetList(opts.link); 
        // store the current view in local storage for state persistence
    },
    saveState: function() {
        var state = this.currentView.getState();
        state.view = this.currentView.viewName;
        window.localStorage.setItem("ww3_cm_state",JSON.stringify(state));
    },
    loadState: function () {
        return JSON.parse(window.localStorage.getItem("ww3_cm_state"));
    },
    updateProblemSetList: function(viewname) {
        switch(viewname){            // set up the problem sets to be draggable or not
            case "calendar":
            //this.setProblemSetUI({droppable:true,draggable: true});
            this.updateCalendar();
            break;
            case "libraryBrowser":
            this.setProblemSetUI({droppable:true,draggable: false});
            break;
            default:
            this.setProblemSetUI({droppable: false, draggable:false});
        }
    },
    // call this to set the problems to be draggable or not or droppable or not: 

    // Note: this should be done in the individual views.  
    setProblemSetUI: function (opts) {
        var self = this;

        // The following allows a problem set (on the sidepane to be dragged onto the Calendar)
        if(opts.draggable){
            $(".problem-set").draggable({ 
                disabled: false,  
                revert: true, 
                scroll: false, 
                helper: "clone",
                appendTo: "body",
                cursorAt: {left: 10, top: 10}
            });
        } else {
            $(".problem-set.ui-draggable").draggable("destroy");
        }
        if(opts.droppable){
            $(".problem-set").droppable({
                disabled: false,
                hoverClass: "btn-info",
                accept: ".problem",
                tolerance: "pointer",
                drop: function( evt, ui ) { 
                    console.log("Adding a Problem to HW set " + $(evt.target).data("setname"));
                    console.log($(ui.draggable).data("path"));
                    var source = $(ui.draggable).data("source");
                    console.log(source);
                    var set = self.problemSets.findWhere({set_id: $(evt.target).data("setname")})
                    var prob = self.views.libraryBrowser.views[source].problemList
                                        .findWhere({source_file: $(ui.draggable).data("path")});
                    set.addProblem(prob);
                }
            });
        } else {
            $(".problem-set.ui-droppable").droppable("destroy");
        }
    }, 
    // This travels through all of the assignments and determines the days that assignment dates fall
    buildAssignmentDates: function () {
        var self = this;
        this.assignmentDateList = new AssignmentDateList();
        this.problemSets.each(function(_set){
            self.assignmentDateList.add(new AssignmentDate({type: "open", problemSet: _set,
                    date: moment.unix(_set.get("open_date")).format("YYYY-MM-DD")}));
            self.assignmentDateList.add(new AssignmentDate({type: "due", problemSet: _set,
                    date: moment.unix(_set.get("due_date")).format("YYYY-MM-DD")}));
            self.assignmentDateList.add(new AssignmentDate({type: "answer", problemSet: _set,
                    date: moment.unix(_set.get("answer_date")).format("YYYY-MM-DD")}));


        });
    },
    // This updates the drag-drop features of the calendar.
    updateCalendar: function ()
    {
        var self = this;
        this.mainViewList.getViewByName("Calendar").render();
        // The following allows each day in the calendar to allow a problem set to be dropped on. 
             
        $(".calendar-day").droppable({
            hoverClass: "highlight-day",
            accept: ".problem-set, .assign",
            greedy: true,
            drop: function(ev,ui) {
                ev.stopPropagation();
                if($(ui.draggable).hasClass("problem-set")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"all");
                } else if ($(ui.draggable).hasClass("assign-open")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"open_date");
                } else if ($(ui.draggable).hasClass("assign-due")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"due_date");
                } else if ($(ui.draggable).hasClass("assign-answer")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"answer_date");
                }

            }
        });

        // The following allows an assignment date (due, open) to be dropped on the calendar

        $(".assign-due,.assign-open,.assign-answer").draggable({
            revert: true,
            start: function () {$(this).popover("destroy")}
        });
    },
    setDate: function(_setName,_date,type){  // sets the date in the form YYYY-MM-DD
        var problemSet = this.problemSets.findWhere({set_id: _setName.toString()});
        if(type==="all") {
            problemSet.setDefaultDates(_date).save({success: this.updateCalendar()});
        } else {
            problemSet.setDate(type,moment(_date,"YYYY-MM-DD").unix());
        }

    }
});

   
var App = new CourseManager({el: $("div#mainDiv")});
});
