/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
define(['module','backbone', 'underscore','models/UserList','models/ProblemSetList','models/SettingList',  
    'models/AssignmentDate','models/AssignmentDateList','views/WebPage','config',
    'main-views/AssignmentCalendarView','main-views/ProblemSetsManager','main-views/LibraryBrowser',
    'main-views/ProblemSetDetailView','main-views/ImportExportView','main-views/ClasslistView','main-views/SettingsView',
    'option-panes/ProblemSetListView','option-panes/UserListView','option-panes/LibraryOptionsView',
    'jquery-ui','bootstrap'
    ], 
function(module, Backbone, _, UserList, ProblemSetList, SettingList,AssignmentDate,AssignmentDateList,WebPage,config,
    AssignmentCalendarView, ProblemSetsManager, LibraryBrowser,ProblemSetDetailView,ImportExportView,ClasslistView,
    SettingsView,ProblemSetListView,UserListView,LibraryOptionsView){
var CourseManager = WebPage.extend({
    tagName: "div",
    initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','updateCalendar','setProblemSetUI', 'setMessages',"showProblemSetDetails",
            "changeView","openOptionPane","loadData","checkData");  // include all functions that need the this object
	    var self = this;

        this.render();
        
        this.session = (module.config().session)? module.config().session : {};
        config.settings = (module.config().settings)? new SettingList(module.config().settings, {parse: true}) : null;
        this.users = (module.config().users) ? new UserList(module.config().users) : null;
        this.problemSets = (module.config().sets) ? new ProblemSetList(module.config().sets,{parse: true}) : null;
        _.extend(config.courseSettings,{course_id: module.config().course_id});
        if(this.session.user){
            this.startManager();
        } else {
            // open the login window. 
            
            this.requestLogin({success: this.loadData});
        }

    },
    loadData: function (data) {
        if(data.logged_in===1){ // logged in successful,  load the data
            this.loginPane.$(".message-bottom").html(config.msgTemplate({type: "loading_data"}))
                .append("<i class='fa fa-spinner fa-spin'></i>");
            this.data_loaded = {settings: false, users: false, problemSets: false};
            this.problemSets.fetch({success: this.checkData});
            config.settings.fetch({success: this.checkData});
            this.users.fetch({success: this.checkData});
            
        } else { // send an error
            this.loginPane.$(".message").html(config.msgTemplate({type: "bad_password"}));
        }
    },
    // wait for all of the data to get loaded in, close the login window, then start the Course Manager. 
    checkData: function (data) {
        if (data instanceof UserList){
            this.data_loaded.users = true;
        } else if (data instanceof ProblemSetList){
            this.data_loaded.problemSets = true;
        } else if (data instanceof Settings){
            this.data_loaded.settings = true;
        }
        console.log(_(this.data_loaded).chain().values().every(_.identity).value());
        if(_(this.data_loaded).chain().values().every(_.identity).value()){
            this.closeLogin();
            this.startManager();
        }
    },
    startManager: function () {

        this.buildAssignmentDates();


        // can't we just pull this from the settings when needed.  Why do we need another variable. 
        config.timezone = config.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    
        // Define all of the views that are visible with the Pulldown menu

        this.views = {
            calendar : new AssignmentCalendarView({el: $("#calendar"), assignmentDates: this.assignmentDateList,
                    viewType: "instructor", calendarType: "month", users: this.users,
                    reducedScoringMinutes: config.settings.find(function(setting) { return setting.get("var")==="pg{ansEvalDefaults}{reducedScoringPeriod}";}).get("value")}),
            setDetails:  new ProblemSetDetailView({el: $("#setDetails"),  users: this.users, problemSets: this.problemSets,
                    headerView: this.headerView}),
            allSets:  new ProblemSetsManager({el:$("#allSets"), problemSets: this.problemSets, users: this.users}),
            importExport:  new ImportExportView({el: $("#importExport"), headerView: this.headerView,
                    problemSets: this.problemSets}),
            libraryBrowser : new LibraryBrowser({el: $("#libraryBrowser"), headerView: this.headerView,
                errorPane: this.errorPane, problemSets: this.problemSets}),
            settings      :  new SettingsView({headerView: this.headerView, el: $("#settings")}),
            classlist: new ClasslistView({el: $("#classlist"), users: this.users, problemSets: this.problemSets})
        };

        this.views.calendar.dispatcher.on("calendar-change", self.updateCalendar);

        // Define all of the option views available for the right side

        this.optionViews = {
            problemSets: new ProblemSetListView({el: $("#problemSets"), problemSets: this.problemSets,
                users: this.users}),
            userList: new UserListView({el: $("#userList"), users: this.users}),
            libraryViewOptions: new LibraryOptionsView({el: $("#libraryViewOptions"), problemSets: this.problemSets})
        }


        this.setMessages();  

        // this will automatically save (sync) any change made to a problem set.
        this.problemSets.on("change",function(_set){
            console.log(_set.changed);
            _set.save();
        })        

        // set the initial view to be the Calendar. 
        this.changeView({link: "calendar",name: "Calendar"});
        this.openOptionPane({link: "problemSets", name: "Problem Sets"});

        this.navigationBar.on("change-view",this.changeView);
        this.navigationBar.on("open-option",this.openOptionPane);

    },
    setMessages: function (){
        var self = this; 

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
            console.log("Yippee!!");

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
            })

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
        });

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
            // change the attributes back to before.
           /* _(_.keys(model.changed)).each(function(key){
                model.set(key,model._previousAttributes[key]);
            })*/
        });

        /* Set the events for the settings */

        config.settings.on("change",function(setting){
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
        this.changeView({link: "setDetails", name: "Set Details"});
        this.views.setDetails.changeHWSet(setName); 
    },
    openOptionPane: function(opts){
        $(".option-pane").removeClass("active");
        $("#"+opts.link).addClass("active");
        (this.currentOptionView = this.optionViews[opts.link]).render()
        this.currentView.setOptionPane(this.currentOptionView);

    },
    changeView: function (opts){
        $(".view-pane").removeClass("active");
        $("#"+opts.link).addClass("active");
        this.navigationBar.setPaneName(opts.name);
        (this.currentView = this.views[opts.link]).render();
        this.updateProblemSetList(opts.link); // why do we need this? 
    },
    updateProblemSetList: function(viewname) {
        switch(viewname){            // set up the problem sets to be draggable or not
            case "calendar":
            this.setProblemSetUI({droppable:true,draggable: true});
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
    setProblemSetUI: function (opts) {
        var self = this;

        // The following allows a problem set (on the left column to be dragged onto the Calendar)
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
    updateAssignmentDates: function (){

    },
    // This updates the drag-drop features of the calendar.
    updateCalendar: function ()
    {
        var self = this;
        this.views.calendar.render();
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
