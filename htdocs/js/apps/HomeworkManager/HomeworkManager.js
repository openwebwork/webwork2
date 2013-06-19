/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
require(['Backbone', 
    'underscore',
    '../globals',
    '../../lib/models/UserList',
    '../../lib/models/ProblemSetList',
    '../../lib/models/Settings',   
    '../../lib/views/AssignmentCalendarView',
    './HWDetailView',
    '../../lib/views/ProblemSetListView',
    './SetListView',
    './LibraryBrowser',
    './AssignUsersView',
    'WebPage',
    'config',
    '../../lib/views/WWSettingsView',
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
	    _.bindAll(this, 'render','postHWLoaded','setDropToEdit','setMessages'
                        ,"showHWdetails");  // include all functions that need the this object
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
        this.setMessages();  
            
    },
    setProblemSetsDragDrop: function () {
        var self = this; 

        // This allows the Problem Sets (in the left column) to accept problems to add a problem to a set.  
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
            self.views.calendar.render();
            self.setDropToEdit();
            var keys = _.keys(_set.changed);
            _(keys).each(function(key) {
                self.announce.addMessage({text: "The value of " + key + " in problem set " + _set.get("set_id") + " has changed to " + _set.changed[key]});    
            });
            self.views.calendar.render();
            self.setDropToEdit();
        });

        // can't figure out the best place for this.  
        /* this.problemSet.problems.on("reordered",function () {
                self.announce.addMessage({text: "Problem Set " + self.parent.problemSet.get("set_id") + " was reordered"});
            });  */

        (this.probSetListView = new ProblemSetListView({el: $("#problem-set-list-container"), viewType: "Instructor",
                                    problemSets: this.problemSets, users: this.users})).render();

        this.postHWLoaded();
        this.setProblemSetsDragDrop();
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
    postHWLoaded: function ()
    {
        
        this.setDropToEdit();        

        this.views = {
            calendar : new AssignmentCalendarView({el: $("#calendar"), problemSets: this.problemSets, 
                    viewType: "instructor", calendarType: "month", users: this.users,
                    reducedScoringMinutes: config.settings.find(function(setting) { return setting.get("var")==="pg{ansEvalDefaults}{reducedScoringPeriod}";}).get("value")}),
            setDetails:  new HWDetailView({el: $("#setDetails"),  users: this.users, problemSets: this.problemSets}),
            allSets:  new SetListView({el:$("#allSets"), collection: this.problemSets, parent: self}),
            assignSets  :  new AssignUsersView({el: $("#assignSets"), id: "view-assign-users", parent: this}),
            importExport:  new ImportExport(),
            libraryBrowser : new LibraryBrowser({el: $("#libraryBrowser"), parent: this, hwManager: this}),
            settings      :  new HWSettingsView({parent: this, el: $("#settings")})
        };


        this.views.calendar.render();
        this.setDropToEdit();
        
        // Set the popover on the set name
        $("span.pop").popover({title: "Homework Set Details", placement: "top", offset: 10});


        // Wait for everything to load until allowing the user to change the view.
        $("#hw-manager-menu button").removeClass("disabled");
               
    },
            // This allows the homework sets generated above to be dragged onto the Calendar to set the due date. 

    setDropToEdit: function ()
    {
        var self = this;

        // The following allows a problem set (on the left column to be dragged onto the Calendar)
        $(".problem-set").draggable({   
            revert: "valid", 
            scroll: false, 
            helper: "clone",
            appendTo: "body",
            cursorAt: {left: 10, top: 10},
            start: function (event,ui) { self.objectDragging=true;},
            stop: function(event, ui) {self.objectDragging=false;}
        });

        // The following allows each day in the calendar to allow a problem set to be dropped on. 
             
        $(".calendar-day").droppable({
            hoverClass: "highlight-day",
            accept: ".problem-set, .assign",
            greedy: true,
            drop: function(ev,ui) {
                ev.stopPropagation();
                if($(ui.draggable).hasClass("problem-set")){
                    self.setDates($(ui.draggable).data("setname"),$(this).data("date"),"all");
                } else if ($(ui.draggable).hasClass("assign-open")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"open_date");
                } else if ($(ui.draggable).hasClass("assign-due")){
                    self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"due_date");
                }

            },
        });

        // The following allows an assignment date (due, open) to be dropped on the calendar

        $(".assign-due,.assign-open").draggable({
            start: function () {$(this).popover("destroy")}
        });


        $("body").droppable({accept: ".problem-set", drop: function () { console.log("dropped");}});

    },
    setDate: function(_setName,_date,type){  // sets the date in the form YYYY-MM-DD
        var problemSet = this.problemSets.findWhere({set_id: _setName.toString()});
        console.log(problemSet);
        problemSet.setDate(type,moment(_date,"YYYY-MM-DD").unix()).update();

    },
    setDates: function(_setName,_date){

        var HWset = this.problemSets.find(function (_set) { return _set.get("set_id") === _setName;})
        HWset.setDefaultDates(_date);
        HWset.update();
        console.log("Changing HW Set " + _setName + " to be due on " + _date);
        this.views.calendar.render();
        this.setDropToEdit();
    
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
