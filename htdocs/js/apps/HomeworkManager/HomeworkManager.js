/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/

require.config({
    paths: {
        "Backbone":             "/webwork2_files/js/lib/vendor/backbone-0.9.9",
        "backbone-validation":  "/webwork2_files/js/lib/vendor/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/lib/vendor/jquery-drag-drop/js/jquery-ui-1.9.2.custom",
        "underscore":           "/webwork2_files/js/lib/vendor/underscore/underscore",
        "jquery":               "/webwork2_files/js/lib/vendor/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/lib/vendor/bootstrap/js/bootstrap",
        "util":                 "/webwork2_files/js/lib/webwork/util",
        "XDate":                "/webwork2_files/js/lib/vendor/xdate",
        "WebPage":              "/webwork2_files/js/lib/webwork/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":            "/webwork2_files/js/lib/webwork/views/Closeable",
        "datepicker":           "/webwork2_files/js/lib/vendor/datepicker/js/bootstrap-datepicker",
        "jquery-truncate":      "/webwork2_files/js/lib/vendor/jquery.truncate.min",
        "jquery-tablesorter":   "/webwork2_files/js/lib/vendor/jquery.tablesorter.min"
    },
    urlArgs: "bust=" +  (new Date()).getTime(),
    waitSeconds: 15,
    shim: {
        'jquery-ui': ['jquery'],
        'underscore': { exports: '_' },
        'Backbone': { deps: ['underscore', 'jquery'], exports: 'Backbone'},
        'bootstrap':['jquery'],
        'backbone-validation': ['Backbone'],
        'XDate':{ exports: 'XDate'},
        'config': ['XDate'],
        'datepicker': ['bootstrap'],
        'jquery-truncate': ['jquery'],
        'jquery-tablesorter': ['jquery']
    }
});

require(['Backbone', 
    'underscore',
    '../../lib/webwork/models/UserList',
    '../../lib/webwork/models/ProblemSetList',
    '../../lib/webwork/models/Settings',   
    '../../lib/webwork/views/CalendarView',
    './HWDetailView',
    '../../lib/webwork/views/ProblemSetListView',
    './SetListView',
    './LibraryBrowser',
    './AssignUsersView',
    'WebPage',
    'config',
    '../../lib/webwork/views/WWSettingsView',
    'backbone-validation',
    'jquery-ui',
    'bootstrap',
    'datepicker'
    ], 
function(Backbone, _,  UserList, ProblemSetList, Settings, CalendarView, HWDetailView, 
            ProblemSetListView,SetListView,LibraryBrowser,AssignUsersView,WebPage,config,WWSettingsView){
    var HomeworkEditorView = WebPage.extend({
	    tagName: "div",
        initialize: function(){
    	    this.constructor.__super__.initialize.apply(this, {el: this.el});
    	    _.bindAll(this, 'render','postHWLoaded','setDropToEdit','setupMessages');  // include all functions that need the this object
    	    var self = this;
            this.dispatcher = _.clone(Backbone.Events);

            this.settings = new Settings();  // need to get other settings from the server.  
            this.problemSets = new ProblemSetList({type: "Instructor"});
            this.settings.fetch();

            this.settings.on("fetchSuccess", function (data){
                self.render();
                self.problemSets.fetch();
                config.timezone = self.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
                self.HWSettingsView.render();
            }); 



            this.dispatcher.on("calendar-change", self.setDropToEdit);

            this.setupMessages();

            this.problemSets.on("fetchSuccess",function() {
                self.problemSets.each(function(_set){
                    _set.countUsers();
                });
                self.setListView.render();
                self.postHWLoaded();
            });


            this.users = new UserList();
            this.users.fetch();
            this.users.on("fetchSuccess", function (data){ console.log("users loaded");}); 
                
        },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
	    var self = this; 
            
        this.probSetListView = new ProblemSetListView({el: $("#left-column"), viewType: "Instructor",
                                    collection: this.problemSets, parent: this});    
        
        $("#settings").html(_.template($("#settings-template").html()));


        $("#hw-manager-menu a.link").on("click", function (evt) {  self.changeView($(evt.target).data("link")) });

        //$("body").droppable();  // This helps in making drags return to their original place.
        
        //new ui.PropertyListView({el: $("#settings"), model: self.settings});

        // render the parts of the Homework Manager. 

        this.HWDetails           = new HWDetailView({el: $("#problem-set"),  collection: this.problemSets,parent: this});
        this.setListView         = new SetListView({el:$("div#hw-set-list"), collection: this.problemSets, parent: self});
        this.libDirectoryBrowser = new LibraryBrowser({el:  $("#view-all-libraries"), id: "view-all-libraries", parent: this});
        this.libSubjectBrowser   = new LibraryBrowser({el:  $("#view-all-subjects"), id: "view-all-subjects", parent: this});
        this.assignUsersView     = new AssignUsersView({el: $("#assign-users"), id: "view-assign-users", parent: this});
        this.HWSettingsView      = new HWSettingsView({parent: self, el: $("#settings-table")});


    },
    changeView: function (linkname){
        $(".view-header").removeClass("active");
        $(".view-header[data-view='" + linkname + "']").addClass("active");
        $(".view-pane").removeClass("active");
        $("#"+linkname).addClass("active");
    },
    addHWSet: function(_set){
        var self = this;
         // Allow problems to be dropped onto homework sets

         console.log("in addHWSet");

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
                    var prob = self[source].problemList.find(function(prob) { return prob.get("path")===$(ui.draggable).data("path");})
                    set.addProblem(prob);
                }
            });

        // When the HW sets are clicked, open the HW details tab.  
        
        $(".problem-set").on('click', function(evt) {
            if (self.objectDragging) return;
            self.changeView("problem-set");
            self.HWDetails.changeHWSet($(evt.target).data("setname")); 

        });

        if (_set) {self.setListView.addSet(_set)};
    },
    setupMessages: function () {
        var self = this;

        this.problemSets.on("problem-set-changed", function (_set){
            
            self.calendarView.updateAssignments();
            self.calendarView.render();
            self.setListView.render();
            self.setDropToEdit();
            var keys = _.keys(_set.changed);
            _(keys).each(function(key) {
                self.announce.addMessage("The value of " + key + " in problem set " + _set.get("set_id") + " has changed to " + _set.changed[key]+ "<br>");    
            })
        });
        
        this.dispatcher.on("problem-set-added", function (set){
            console.log("this.dispatcher");
            self.announce.addMessage("The HW set with name " + set.get("set_id") + " was created.");
            self.addHWSet(set); // update all other parts of the part with the new set.
                
        });

        this.problemSets.on("problem-set-deleted",function(set){
            self.announce.addMessage("The HW set with name " + set.get("set_id") + " was deleted.");
        });

    },
    postHWLoaded: function ()
    {
        var self = this;

        this.addHWSet();
 
        self.calendarView = new CalendarView({el: $("#calendar"), parent: this, 
                collection: this.problemSets, view: "instructor"});
        
        self.setDropToEdit();        
        

        // Set the popover on the set name
        $("span.pop").popover({title: "Homework Set Details", placement: "top", offset: 10});
        
        

        // Create the HW details pane. 

        $("#details").html(_.template($("#HW-detail-template").html()));  

        this.assignUsersView.initializeModel();
        this.assignUsersView.render();

    },
            // This allows the homework sets generated above to be dragged onto the Calendar to set the due date. 

    setDropToEdit: function ()
    {
        var self = this;

        // The following helps determine if a problem set is being dragged or clicked on. 
        $(".problem-set").draggable({revert: "valid", start: function (event,ui) { self.objectDragging=true;},
                                stop: function(event, ui) {self.objectDragging=false;}});
             
        $(".calendar-day").droppable({
            hoverClass: "highlight-day",
            accept: ".problem-set",
            greedy: true,
            drop: function(ev,ui) {
                var setName = $(ui.draggable).data("setname");
                var timeAssignDue = self.settings.getSettingValue("pg{timeAssignDue}");
                var theDueDate = /date-(\d{4})-(\d\d)-(\d\d)/.exec($(this).attr("id"));
                var assignOpenPriorToDue = self.settings.getSettingValue("pg{assignOpenPriorToDue}");
                var answerAfterDueDate = self.settings.getSettingValue("pg{answersOpenAfterDueDate}");                
                var wwDueDate = theDueDate[2]+"/"+theDueDate[3] +"/"+theDueDate[1] + " at " + timeAssignDue + " " + config.timezone;
                var HWset = self.problemSets.find(function (_set) { return _set.get("set_id") === setName;});

                console.log("Changing HW Set " + setName + " to be due on " + wwDueDate);
                var _openDate = new XDate(wwDueDate);
                _openDate.addMinutes(-1*assignOpenPriorToDue);
                var _answerDate = new XDate(wwDueDate);
                _answerDate.addMinutes(answerAfterDueDate);
                var tz = /\((\w{3})\)/.exec(_openDate.toString());
                var wwOpenDate = _openDate.toString("MM/dd/yyyy") + " at " + _openDate.toString("hh:mmtt")+ " " + tz[1];
                var wwAnswerDate = _answerDate.toString("MM/dd/yyyy") + " at " + _answerDate.toString("hh:mmtt") + " " + tz[1];

                HWset.set({due_date:wwDueDate, open_date: wwOpenDate, answer_date: wwAnswerDate});
                ev.stopPropagation();
            },
        });


        $("body").droppable({accept: ".problem-set", drop: function () { console.log("dropped");}});

    },
    convertTimeToMinutes: function(timeStr){
        var vals = /(\d+)\s(day|days|week|weeks)/.exec(timeStr);
        var num = parseInt(vals[1]);
        var unit = vals[2];
        switch(unit){
            case "days": case "day": num *= 24*60;  break;
            case "weeks": case "week": num *= 24*7*60; break;
        }
        return num;
    }
});

var HWSettingsView = WWSettingsView.extend({
    initialize: function () {
//        _.bindAll(this,'render','edit');
        this.parent = this.options.parent; 
        this.settings = this.parent.settings.filter(function (setting) {return setting.get("category")==='PG - Problem Display/Answer Checking'});
        this.constructor.__super__.initialize.apply(this,{settings: this.settings});
        console.log(this.settings);
     }, 
     render: function () {
        this.constructor.__super__.render.apply(this);
     }

});


// The following is probably not needed. 

/*
var HWProblemView = Backbone.View.extend({
    className: "set-detail-problem-view",
    tagName: "div",
    
    initialize: function () {
        _.bindAll(this,"render");
        var self = this;
        this.render();
        this.model.on('rendered', function () {
            self.$el.html(self.model.get("data"));
        })
    },
    render: function () {
        this.$el.html(this.model.get("path"));
        this.model.render();
    }


}); */

    
    
    var App = new HomeworkEditorView({el: $("div#mainDiv")});
});
