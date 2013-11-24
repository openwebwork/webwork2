/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
define(['module','Backbone', 'underscore','models/UserList','models/ProblemSetList','models/Settings',   
    'views/AssignmentCalendarView','HWDetailView','views/ProblemSetListView','SetListView','LibraryBrowser',
    'views/WebPage','config','views/WWSettingsView','views/HeaderView','models/ProblemSet',
    'models/AssignmentDate','models/AssignmentDateList','ImportExportView',
    'backbone-validation','jquery-ui','bootstrap'
    ], 
function(module, Backbone, _, UserList, ProblemSetList, Settings, AssignmentCalendarView, HWDetailView, 
            ProblemSetListView,SetListView,LibraryBrowser,WebPage,config,WWSettingsView,HeaderView,
            ProblemSet, AssignmentDate,AssignmentDateList,ImportExportView){
var HomeworkEditorView = WebPage.extend({
    tagName: "div",
    initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','updateCalendar','setProblemSetUI', 'setMessages',"showHWdetails");  // include all functions that need the this object
	    var self = this;

        (this.headerView = new HeaderView({el: $("#page-header")})).setTemplate({template: "#calendar-header"});
        this.render();
        this.dispatcher = _.clone(Backbone.Events);

        config.settings = new Settings();
        if (module.config().settings){
            config.settings.parseSettings(module.config().settings);
        }
        this.users = (module.config().users) ? new UserList(module.config().users) : new UserList();
        this.problemSets = new ProblemSetList();
        if (module.config().sets) {
            this.problemSets.parse(module.config().sets);
        }
        this.buildAssignmentDates();

        // call parse to set the .id attribute of each set so that backbone's set.isNew()  is false
        config.settings.each(function(setting){setting.parse();});
        this.users.each(function(user){user.parse();});

        config.timezone = config.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    
                // Define all of the views that are visible with the Pulldown menu

        this.views = {
            calendar : new AssignmentCalendarView({el: $("#calendar"), assignmentDates: this.assignmentDateList,
                    viewType: "instructor", calendarType: "month", users: this.users,
                    reducedScoringMinutes: config.settings.find(function(setting) { return setting.get("var")==="pg{ansEvalDefaults}{reducedScoringPeriod}";}).get("value")}),
            setDetails:  new HWDetailView({el: $("#setDetails"),  users: this.users, problemSets: this.problemSets,
                    headerView: this.headerView}),
            allSets:  new SetListView({el:$("#allSets"), problemSets: this.problemSets, users: this.users}),
            importExport:  new ImportExportView({el: $("#importExport"), headerView: this.headerView,
                    problemSets: this.problemSets}),
            libraryBrowser : new LibraryBrowser({el: $("#libraryBrowser"), headerView: this.headerView,
                errorPane: this.errorPane, problemSets: this.problemSets}),
            settings      :  new SettingsView({parent: this, el: $("#settings")})
        };

        this.views.calendar.dispatcher.on("calendar-change", self.updateCalendar);

        this.setMessages();  
        (this.probSetListView = new ProblemSetListView({el: $("#problem-set-list-container"), viewType: "Instructor",
                            problemSets: this.problemSets, users: this.users})).render();


        // this will automatically save (sync) any change made to a problem set.
        this.problemSets.on("change",function(_set){
            _set.save();
        })        

        // set the initial view to be the Calendar. 
        this.changeView(null,"calendar","Calendar");

        // this is needed for the handshaking of session information between the old and new
        // webservice

        // this pulls the course_id from the URL and we need to have a more general way to get this from either 
        // ww2 or ww3 

        _.extend(config.courseSettings,{course_id: location.href.match(/\/webwork2\/(\w+)\//)[1]});
        $.post(config.urlPrefix + "handshake?"+$.param(config.courseSettings),
                function(response){
                    console.log(response);
                });

            
    },
    setMessages: function (){
        var self = this; 
        this.problemSets.on("add", function (_set){
            _set.save();
            _set.changingAttributes={add: "Set Added"};
        });

        this.problemSets.on("remove", function(_set){
            if(_set.destroy()){
                self.messagePane.addMessage({type: "success", short: "Set " + _set.get("set_id") + " removed.",
                    text: "Problem Set: " + _set.get("set_id") + " has been removed from the course."});

            // update the assignmentDateList to delete the proper assignments

                self.assignmentDateList.remove(self.assignmentDateList.filter(function(assign) { 
                    return assign.get("problemSet").get("set_id")===_set.get("set_id");}));
            }
        });

        this.problemSets.on("change:due_date change:open_date change:answer_date",function(_set){
            var assignments = self.assignmentDateList.filter(function(assign) { 
                    return assign.get("problemSet").get("set_id")===_set.get("set_id");});
            _(assignments).each(function(assign){
                assign.set("date",moment.unix(assign.get("problemSet").get(assign.get("type")+"_date")).format("YYYY-MM-DD"));
            });
        });

        this.problemSets.on("change_assigned_users", function(_set){
            console.log("the set "+ _set.get("set_id")+ " has changed.");
        });

        this.problemSets.each(function(_set) {
            _set.get("problems").on("change:value",function(prob){
                prob.changingAttributes=_.pick(prob._previousAttributes,_.keys(prob.changed));
            });
            _set. get("problems").on("sync",function(prob){
                _(_.keys(prob.changingAttributes)).each(function(key){
                    self.messagePane.addMessage({type: "success", short: "Set " + prob.collection.setName + " saved.",
                        text: "Problem Set " + prob.collection.setName + " and problem " + prob.get("problem_id") 
                            + " has changed. The value of property " + key 
                            + " has changed from " + prob.changingAttributes[key] + " to " 
                            + prob.get(key) });
                });
            });
        });

        this.problemSets.on("change",function(_set){
           _set.changingAttributes=_.pick(_set._previousAttributes,_.keys(_set.changed));
        });

        
        this.problemSets.on("sync", function (_set){
            _(_.keys(_set.changingAttributes||{})).each(function(key){
                switch(key){
                    case "problems":
                        self.messagePane.addMessage({type: "success", short: "Set " + _set.get("set_id") + " saved.",
                            text: attr.msg});
                        break;
                    case "assigned_users":
                        self.messagePane.addMessage({type: "success", short: "Set " + _set.get("set_id") + " saved.",
                            text: "The assigned users for set " + _set.get("set_id") + " was updated."});
                        break;
                    case "add":
                        self.messagePane.addMessage({type: "success", short: "Set " + _set.get("set_id") + " added.",
                        text: "The set " + _set.get("set_id") + " was added to the course."});
                        self.assignmentDateList.add(new AssignmentDate({type: "open", problemSet: _set,
                            date: moment.unix(_set.get("open_date")).format("YYYY-MM-DD")}));
                        self.assignmentDateList.add(new AssignmentDate({type: "due", problemSet: _set,
                            date: moment.unix(_set.get("due_date")).format("YYYY-MM-DD")}));
                        self.assignmentDateList.add(new AssignmentDate({type: "answer", problemSet: _set,
                            date: moment.unix(_set.get("answer_date")).format("YYYY-MM-DD")}));

                        break;
                    default:
                        var _old = key.match(/date$/) ? moment.unix(_set.changingAttributes[key]).format("MM/DD/YYYY")
                                     : _set.changingAttributes[key];
                        var _new = key.match(/date$/) ? moment.unix(_set.get(key)).format("MM/DD/YYYY") : _set.get(key);
                        self.messagePane.addMessage({type: "success", short: "Set " + _set.get("set_id") + " saved.",
                            text: "The value of " + key + " in problem set " 
                            + _set.get("set_id") + " has changed from " + _old + " to " + _new});
                }
            });
            self.updateCalendar();
        });

        // this will show the given Problem Set sent from "Manage Problem Sets (HWDetailView) or ProblemSetListView"

        this.problemSets.on("show",function(_set){
            self.showHWdetails(_set.get("set_id"));
        });

        // this handles the validation of the problem sets, mainly validating the dates.  



        this.problemSets.bind('validated:invalid', function(model, errors) {
            var uniqueErrors = _.unique(_.values(errors));
            _(uniqueErrors).each(function(error){
                self.messagePane.addMessage({type: "error", short: "Error saving problem set " + model.get("set_id"),
                    text: error});

            }); 
            // change the attributes back to before.
           /* _(_.keys(model.changed)).each(function(key){
                model.set(key,model._previousAttributes[key]);
            })*/
        });

        config.settings.on("change",function(setting){
            setting.changingAttributes=_.pick(setting._previousAttributes,_.keys(setting.changed));
        });

        config.settings.on("sync",function(setting){
            _(_.keys(setting.changingAttributes)).each(function(key){
                    self.messagePane.addMessage({type: "success", short: "Setting " + setting.get("var") + " saved.",
                        text: "The setting " + setting.get("var") + " has changed from " +
                                setting.changingAttributes[key] + " to " + setting.get("value") + "."});
            });
        });

    },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
        this.headerView.render();
    },
    events: {"click #hw-manager-menu a.link": "changeView",
            "click #show-hide-sets-button": "showHideSets"},
    showHideSets: function () {
        if ($("#problem-set-list-container").css("display")=="none"){
            $("#problem-set-list-container").show("slide",{direction: "up"});
            $("#show-hide-sets-button i").removeClass("fa fa-chevron-down").addClass("fa fa-chevron-up");            
        } else {
            $("#problem-set-list-container").hide("slide", { direction: "up" });
            $("#show-hide-sets-button i").removeClass("fa fa-chevron-up").addClass("fa fa-chevron-down");            
        }

    },
    showHWdetails: function(setName){
        if (this.objectDragging) return;
        this.changeView(null,"setDetails", "Set Details");
        this.views.setDetails.changeHWSet(setName); 
        this.headerView.setTemplate(this.views.setDetails.headerInfo).render();

    },
    changeView: function (evt,link,header){
        var linkname = (link)?link:$(evt.target).data("link");
        $(".view-pane").removeClass("active");
        $("#"+linkname).addClass("active");
        $("#viewHeader").html(((header)?header:$(evt.target).data("name"))+"<i class='fa fa-chevron-down'></i>")
            .data("linkname",linkname);
        this.views[linkname].render();
        this.headerView.setTemplate(this.views[linkname].headerInfo).render();
        this.updateProblemSetList(linkname);
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
                console.log("changing the date of a problem set");
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
        console.log(problemSet);
        if(type==="all") {
            problemSet.setDefaultDates(_date).save({success: this.updateCalendar()});
        } else {
            // check first to see if a valid date has been selected. 
            /*if(!moment.unix(problemSet.get("open_date")).isBefore(moment.unix(problemSet.get("due_date")))){
                this.errorPane.addMessage({text: "Oops!!"});
            } */

            problemSet.setDate(type,moment(_date,"YYYY-MM-DD").unix());
        }

    }
});

var SettingsView = Backbone.View.extend({
    headerInfo: {template: "#settings-header"},
    initialize: function () {
        _.bindAll(this,'render');


        this.settings = config.settings.filter(function (setting) {return setting.get("category")==='PG - Problem Display/Answer Checking'});
        this.constructor.__super__.initialize.apply(this,{settings: this.settings});
     }, 
     render: function () {
        // get all of the categories except for timezone (include it somewhere?)
        var categories = config.settings.chain().pluck("attributes").pluck("category")
            .unique().difference("timezone").value();
        $("#settings").html(_.template($("#settings-template").html(),{categories: categories}));
        this.constructor.__super__.render.apply(this);

        // set up the general settings tab

        $("#setting-tab0").addClass("active");  // show the first settings pane.
        $("a[href='#setting-tab0']").parent().addClass("active");

        var settings = config.settings.where({category: categories[0]});
        this.$(".tab-content .active").empty().append((new WWSettingsView({settings: settings})).render().el);

     },
     events: {"shown a[data-toggle='tab']": "changeSettingTab"},
     changeSettingTab: function(evt){
        var settings = config.settings.where({category: $(evt.target).text()});
        this.$(".tab-content .active").empty().append((new WWSettingsView({settings: settings})).render().el);

     }
});

    
    var App = new HomeworkEditorView({el: $("div#mainDiv")});
});
