/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
require(['Backbone', 
    'underscore',
    'apps/globals',
    'models/UserList',
    'models/ProblemSetList',
    'models/Settings',   
    'views/AssignmentCalendarView',
    'HWDetailView',
    'views/ProblemSetListView',
    'SetListView',
    'LibraryBrowser',
    'AssignUsersView',
    'views/WebPage',
    'config',
    'views/WWSettingsView',
    'backbone-validation',
    'jquery-ui',
    'bootstrap'
    ], 
function(Backbone, _,  globals, UserList, ProblemSetList, Settings, AssignmentCalendarView, HWDetailView, 
            ProblemSetListView,SetListView,LibraryBrowser,AssignUsersView,WebPage,config,WWSettingsView){
var HomeworkEditorView = WebPage.extend({
    tagName: "div",
    initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','updateCalendar','updateProblemSetList', 'setMessages',"showHWdetails");  // include all functions that need the this object
	    var self = this;
        this.render();
        this.dispatcher = _.clone(Backbone.Events);

        config.settings = new Settings();
        if (globals.settings){
            config.settings.parseSettings(globals.settings);
        }
        this.users = (globals.users) ? new UserList(globals.users): new UserList();
        this.problemSets = (globals.sets) ? new ProblemSetList(globals.sets) : new ProblemSetList();

        this.dispatcher.on("calendar-change", self.setDropToEdit);
        config.timezone = config.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    
        this.render();
                // Define all of the views that are visible with the Pulldown menu

        this.views = {
            calendar : new AssignmentCalendarView({el: $("#calendar"), problemSets: this.problemSets, 
                    viewType: "instructor", calendarType: "month", users: this.users,
                    reducedScoringMinutes: config.settings.find(function(setting) { return setting.get("var")==="pg{ansEvalDefaults}{reducedScoringPeriod}";}).get("value")}),
            setDetails:  new HWDetailView({el: $("#setDetails"),  users: this.users, problemSets: this.problemSets}),
            allSets:  new SetListView({el:$("#allSets"), problemSets: this.problemSets}),
            assignSets  :  new AssignUsersView({el: $("#assignSets"), id: "view-assign-users", parent: this}),
            importExport:  new ImportExport(),
            libraryBrowser : new LibraryBrowser({el: $("#libraryBrowser"), parent: this, hwManager: this}),
            settings      :  new HWSettingsView({parent: this, el: $("#settings")})
        };

        this.setMessages();  
        (this.probSetListView = new ProblemSetListView({el: $("#problem-set-list-container"), viewType: "Instructor",
                            problemSets: this.problemSets, users: this.users})).render();

        this.updateProblemSetList();
        this.updateCalendar();
            
    },
    setMessages: function (){
        var self = this; 
        this.problemSets.on("add", function (set){
            self.announce.addMessage("Problem Set: " + set.get("set_id") + " has been added to the course.");
            self.probSetListView.render();
            self.setProblemSetsDragDrop();
        });

        this.problemSets.on("remove", function(set){
            self.announce.addMessage("Problem Set: " + set.get("set_id") + " has been removed from the course.");
            self.views.calendar.render();
            self.setDropToEdit();
        });
        
        this.problemSets.on("saved", function (_set){
            var keys = _.keys(_set.changed);
            _(keys).each(function(key) {
                if (/date/.test(key)){
                    self.announce.addMessage({text: "The value of " + key + " in problem set " + _set.get("set_id") 
                            + " has changed to " + moment.unix(_set.changed[key]).format("MM/DD/YYYY")});    
                } else {
                    self.announce.addMessage({text: "The value of " + key + " in problem set " + _set.get("set_id") + " has changed to " + _set.changed[key]});    
                }
            });

            self.updateCalendar();
            self.updateProblemSetList();

        });

        // can't figure out the best place for this.  
        /* this.problemSet.problems.on("reordered",function () {
                self.announce.addMessage({text: "Problem Set " + self.parent.problemSet.get("set_id") + " was reordered"});
            });  */
    },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
    },
    events: {"click #hw-manager-menu a.link": "changeView"},
    showHWdetails: function(evt){
        if (this.objectDragging) return;
        this.changeView(null,"setDetails", "Set Details");
        this.views.setDetails.render();
        this.views.setDetails.changeHWSet($(evt.target).closest(".problem-set").data("setname")); 
    },
    changeView: function (evt,link,header){
        var linkname = (link)?link:$(evt.target).data("link");
        $(".view-pane").removeClass("active");
        $("#"+linkname).addClass("active");
        $("#viewHeader").html((header)?header:$(evt.target).data("name"));
        this.views[linkname].render();
    },
    // This rerenders the problem set list on the left and sets the drag and drop properties.
    updateProblemSetList: function () {
        var self = this;
        this.probSetListView.render();

        // The following allows a problem set (on the left column to be dragged onto the Calendar)
        $(".problem-set").draggable({   
            revert: true, 
            scroll: false, 
            helper: "clone",
            appendTo: "body",
            cursorAt: {left: 10, top: 10},
            start: function (event,ui) { self.objectDragging=true;},
            stop: function(event, ui) {
                console.log("in stop");
                self.objectDragging=false;
            }
        });

        // allows the problem sets on the left column to accept problems dropped on them. 

        $(".problem-set").droppable({
            hoverClass: "btn-info",
            accept: ".problem",
            tolerance: "pointer",
            drop: function( event, ui ) { 
                console.log("Adding a Problem to HW set " + $(event.target).data("setname"));
                console.log($(ui.draggable).data("path"));
                var source = $(ui.draggable).data("source");
                console.log(source);
                var set = self.problemSets.find(function (set) { return set.get("set_id")===""+$(event.target).data("setname");});
                var prob = self.views.libraryBrowser.views[source].problemList.find(function(prob) 
                        { return prob.get("path")===$(ui.draggable).data("path");});
                set.addProblem(prob);
            }
        });
        // When the HW sets are clicked, open the HW details tab.          
        $(".problem-set").on('click', self.showHWdetails);


    },
    // This rerenders the calendar and updates the drag-drop features of it.
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
                console.log("in drop");
                ev.stopPropagation();
                if($(ui.draggable).hasClass("problem-set")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"all");
                } else if ($(ui.draggable).hasClass("assign-open")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"open_date");
                } else if ($(ui.draggable).hasClass("assign-due")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"due_date");
                }

            }
        });

        // The following allows an assignment date (due, open) to be dropped on the calendar

        $(".assign-due,.assign-open").draggable({
            revert: true,
            start: function () {$(this).popover("destroy")}
        });
    },
    setDate: function(_setName,_date,type){  // sets the date in the form YYYY-MM-DD
        var problemSet = this.problemSets.findWhere({set_id: _setName.toString()});
        console.log(problemSet);
        if(type==="all") {
            problemSet.setDefaultDates(_date).update();
        } else {
            problemSet.setDate(type,moment(_date,"YYYY-MM-DD").unix()).update();
        }

    }
});

var HWSettingsView = WWSettingsView.extend({
    initialize: function () {
        _.bindAll(this,'render');

        this.settings = config.settings.filter(function (setting) {return setting.get("category")==='PG - Problem Display/Answer Checking'});
        this.constructor.__super__.initialize.apply(this,{settings: this.settings});
     }, 
     render: function () {
        $("#settings").html(_.template($("#settings-template").html()));
        this.constructor.__super__.render.apply(this);

    
     }

});

var ImportExport = Backbone.View.extend({
    initialize: function (){
        _.bindAll(this,"render");
    },
    render: function () {

    }
});

    
    var App = new HomeworkEditorView({el: $("div#mainDiv")});
});
