/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/

require.config({
    paths: {
        "Backbone":             "/webwork2_files/js/vendor/backbone/backbone",
        "backbone-validation":  "/webwork2_files/js/vendor/backbone/modules/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/vendor/jquery/jquery-ui",
        "underscore":           "/webwork2_files/js/vendor/underscore/underscore",
        "jquery":               "/webwork2_files/js/vendor/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/vendor/bootstrap/js/bootstrap",
        "util":                 "/webwork2_files/js/lib/util",
        "XDate":                "/webwork2_files/js/vendor/other/xdate",
        "WebPage":              "/webwork2_files/js/lib/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":            "/webwork2_files/js/lib/views/Closeable",
        "datepicker":           "/webwork2_files/js/vendor/datepicker/js/bootstrap-datepicker",
        "jquery-truncate":      "/webwork2_files/js/vendor/jquery/modules/jquery.truncate.min",
        "jquery-tablesorter":   "/webwork2_files/js/vendor/jquery/modules/jquery.tablesorter.min",
        "jquery-imagesloaded":  '/webwork2_files/js/vendor/jquery/modules/jquery.imagesloaded.min'
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
        'config': { deps: ['XDate'], exports: 'config'},
        'datepicker': ['bootstrap'],
        'jquery-truncate': ['jquery'],
        'jquery-tablesorter': ['jquery'],
        'jquery-imagesloaded': { deps: ['jquery'], exports: 'jquery-imagesloaded'}
    }
});

require(['Backbone', 
    'underscore',
    '../../lib/models/UserList',
    '../../lib/models/ProblemSetList',
    '../../lib/models/Settings',   
    '../../lib/views/CalendarView',
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
    'bootstrap',
    'datepicker'
    ], 
function(Backbone, _,  UserList, ProblemSetList, Settings, CalendarView, HWDetailView, 
            ProblemSetListView,SetListView,LibraryBrowser,AssignUsersView,WebPage,config,WWSettingsView){
var HomeworkEditorView = WebPage.extend({
    tagName: "div",
    initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','postHWLoaded','setDropToEdit','setupMessages','postSettingsFetched',
                        'postProblemSetsFetched',"showHWdetails");  // include all functions that need the this object
	    var self = this;
        this.dispatcher = _.clone(Backbone.Events);

        this.settings = new Settings();  // need to get other settings from the server.  
        this.settings.fetch();
        this.settings.on("fetchSuccess",this.postSettingsFetched);
        this.problemSets = new ProblemSetList({type: "Instructor"});
        
        /* There's a lot of things that need to be loaded as the App starts:
         *    1. The settings
         *    2. The ProblemSets
         *    3. The set of assigned Users for each Problem Set
         *    4. All Users of the course
         *
         *   The tricky part is to load all of these but don't wait until everything is loaded to show the page. 
         *
         */ 



        this.dispatcher.on("calendar-change", self.setDropToEdit);
        this.users = new UserList();
        this.users.fetch();
        this.users.on("fetchSuccess", function (data){ console.log("users loaded");}); 
            
    },
    postSettingsFetched: function (collection, response, options){
        this.render();
        this.problemSets.fetch();
        this.problemSets.on("fetchSuccess",this.postProblemSetsFetched);
        config.timezone = this.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    },
    postProblemSetsFetched: function (data){
        var self=this;
        var setsLoaded = [];
        $("#progressbar").progressbar({max: this.problemSets.size()});
        this.problemSets.each(function(_set,i){
            setsLoaded.push({set: _set.get("set_id"), loaded: false, pos: i}); 
            _set.getAssignedUsers();
            _set.on("usersLoaded", function(set){  // wait for all of the users to be loaded and set the progress bar. 

                console.log("users Loaded for set " + set.get("set_id"));
                var foundSet = _(setsLoaded).find(function(obj){ return obj["set"]===set.get("set_id")});
                setsLoaded[foundSet.pos].loaded = true;
                $("#progressbar").progressbar(
                      {value: _(_(setsLoaded).pluck("loaded")).countBy(function(el) { return el===true;}).true});
                if(_(_(setsLoaded).pluck("loaded")).all()) {self.postHWLoaded();}
            });
        });
        this.problemSets.on("problem-set-added", function (set){
            self.probSetListView.render();
        });

        this.problemSets.on("problem-set-deleted", function(){
            self.views.calendar.updateAssignments();
            self.views.calendar.render();
        });
        
        // set up messages associated with problem Sets.  
        this.setupMessages();

        
        this.problemSets.on("rendered",function(){
            console.log("after rendering");
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

        });

        this.probSetListView.render();
    },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
	    var self = this; 
            
        this.probSetListView = new ProblemSetListView({el: $("#hw-set-list-container"), viewType: "Instructor",
                                    collection: this.problemSets, parent: this});
        this.probSetListView.render();   
        
        // render the parts of the Homework Manager. 


    },
    events: {"click #hw-manager-menu a.link": "changeView"},
    showHWdetails: function(evt){
        if (this.objectDragging) return;
        this.changeView(null,"setDetails", "Set Details");
        this.views.setDetails.render();
        this.views.setDetails.changeHWSet($(evt.target).data("setname")); 
    },
    changeView: function (evt,link,header){
        var linkname = (link)?link:$(evt.target).data("link");
        //$(".view-header").removeClass("active");
        //$(".view-header[data-view='" + linkname + "']").addClass("active");
        $(".view-pane").removeClass("active");
        $("#"+linkname).addClass("active");
        $("#viewHeader").html((header)?header:$(evt.target).data("name"));
        this.views[linkname].render();
    },
    setupMessages: function () {
        var self = this;

        this.problemSets.on("problem-set-changed", function (_set){
            
            self.views.calendar.updateAssignments();
            self.views.calendar.render();
            self.views.allSets.render();
            self.setDropToEdit();
            var keys = _.keys(_set.changed);
            _(keys).each(function(key) {
                self.announce.addMessage({text: "The value of " + key + " in problem set " + _set.get("set_id") + " has changed to " + _set.changed[key]});    
            })
        });
        
        this.problemSets.on("problem-set-added", function (set){
            self.announce.addMessage({text: "The HW set with name " + set.get("set_id") + " was created."});
        });

        this.problemSets.on("problem-set-deleted",function(set){
            self.announce.addMessage({text: "The HW set with name " + set.get("set_id") + " was deleted."});
        });

    },
    postHWLoaded: function ()
    {
        
        this.setDropToEdit();        

        this.views = {
            calendar : new CalendarView({el: $("#calendar"), parent: this, collection: this.problemSets, view: "instructor", viewType: "month"}),
            setDetails:  new HWDetailView({el: $("#setDetails"),  hwManager: this}),
            allSets:  new SetListView({el:$("#allSets"), collection: this.problemSets, parent: self}),
            assignSets  :  new AssignUsersView({el: $("#assignSets"), id: "view-assign-users", parent: this}),
            importExport:  new ImportExport(),
            libraryBrowser : new LibraryBrowser({el: $("#libraryBrowser"), parent: this, hwManager: this}),
            settings      :  new HWSettingsView({parent: this, el: $("#settings")})
        };


        this.views.calendar.render();
        
        // Set the popover on the set name
        $("span.pop").popover({title: "Homework Set Details", placement: "top", offset: 10});
               
    },
            // This allows the homework sets generated above to be dragged onto the Calendar to set the due date. 

    setDropToEdit: function ()
    {
        var self = this;

        // The following helps determine if a problem set is being dragged or clicked on. 
        $(".problem-set").draggable(
            {revert: "valid", 
             scroll: false, 
             helper: "clone",
             appendTo: "body",
            start: function (event,ui) { self.objectDragging=true;},
            stop: function(event, ui) {self.objectDragging=false;}});
             
        $(".calendar-day").droppable({
            hoverClass: "highlight-day",
            accept: ".problem-set",
            greedy: true,
            drop: function(ev,ui) {
                ev.stopPropagation();
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
                var tz = config.timezone;
                var wwOpenDate = _openDate.toString("MM/dd/yyyy") + " at " + _openDate.toString("hh:mmtt")+ " " + tz;
                var wwAnswerDate = _answerDate.toString("MM/dd/yyyy") + " at " + _answerDate.toString("hh:mmtt") + " " + tz;

                HWset.set({due_date:wwDueDate, open_date: wwOpenDate, answer_date: wwAnswerDate});
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
        _.bindAll(this,'render');

        this.settings = this.options.parent.settings.filter(function (setting) {return setting.get("category")==='PG - Problem Display/Answer Checking'});
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
