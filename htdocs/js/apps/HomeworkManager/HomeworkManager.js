/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
define(['module','Backbone', 'underscore','models/UserList','models/ProblemSetList','models/Settings',   
    'views/AssignmentCalendarView','HWDetailView','views/ProblemSetListView','SetListView','LibraryBrowser',
    'AssignUsersView','views/WebPage','config','views/WWSettingsView','views/HeaderView', 
    'backbone-validation','jquery-ui','bootstrap'
    ], 
function(module, Backbone, _, UserList, ProblemSetList, Settings, AssignmentCalendarView, HWDetailView, 
            ProblemSetListView,SetListView,LibraryBrowser,AssignUsersView,WebPage,config,WWSettingsView,HeaderView){
var HomeworkEditorView = WebPage.extend({
    tagName: "div",
    initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render','updateCalendar','updateProblemSetList', 'setMessages',"showHWdetails");  // include all functions that need the this object
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

        // call parse to set the .id attribute of each set so that backbone's set.isNew()  is false
        config.settings.each(function(setting){setting.parse();});
        this.users.each(function(user){user.parse();});

        this.dispatcher.on("calendar-change", self.updateProblemSetList);
        config.timezone = config.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    
                // Define all of the views that are visible with the Pulldown menu

        this.views = {
            calendar : new AssignmentCalendarView({el: $("#calendar"), problemSets: this.problemSets, 
                    viewType: "instructor", calendarType: "month", users: this.users,
                    reducedScoringMinutes: config.settings.find(function(setting) { return setting.get("var")==="pg{ansEvalDefaults}{reducedScoringPeriod}";}).get("value")}),
            setDetails:  new HWDetailView({el: $("#setDetails"),  users: this.users, problemSets: this.problemSets,
                    headerView: this.headerView}),
            allSets:  new SetListView({el:$("#allSets"), problemSets: this.problemSets, users: this.users}),
            assignSets  :  new AssignUsersView({el: $("#assignSets"), id: "view-assign-users", 
                                users: this.users, problemSets: this.problemSets}),
            importExport:  new ImportExport(),
            libraryBrowser : new LibraryBrowser({el: $("#libraryBrowser"), headerView: this.headerView,
                errorPane: this.errorPane, problemSets: this.problemSets}),
            settings      :  new HWSettingsView({parent: this, el: $("#settings")})
        };

        this.setMessages();  
        (this.probSetListView = new ProblemSetListView({el: $("#problem-set-list-container"), viewType: "Instructor",
                            problemSets: this.problemSets, users: this.users})).render();

        


        this.updateProblemSetList();
        this.updateCalendar();

        // this is needed for the handshaking of session information between the old and new
        // webservice

        $.get(config.urlPrefix + "login?"+$.param(config.courseSettings),function(response){
            console.log(response);
        });

            
    },
    setMessages: function (){
        var self = this; 
        this.problemSets.on("add", function (set){
            if (set.save()){
                self.announce.addMessage({text: "Problem Set: " + set.get("set_id") + " has been added to the course."});
                self.probSetListView.render();
                self.updateProblemSetList();
            }

        });

        this.problemSets.on("remove", function(set){
            if(set.destroy()){
                self.announce.addMessage({text: "Problem Set: " + set.get("set_id") + " has been removed from the course."});
                self.views.calendar.render();
                self.updateProblemSetList();
            }
        });

        this.problemSets.on("change_assigned_users", function(_set){
            console.log("the set "+ _set.get("set_id")+ " has changed.");
        })
        
        this.problemSets.on("sync", function (_set){
            console.log("Synched!!!");
            _(_set.alteredAttributes).each(function(attr){
                    var _old = attr.attr.match(/date$/) ? moment.unix(attr.old_value).format("MM/DD/YYYY") : attr.old_value;
                    var _new = attr.attr.match(/date$/) ? moment.unix(attr.new_value).format("MM/DD/YYYY") : attr.new_value;
                    self.announce.addMessage({text: "The value of " + attr.attr + " in problem set " 
                        + _set.get("set_id") + " has changed from " + _old + " to " + _new});
                });
            //self.updateCalendar();
            self.updateProblemSetList();

        });

        // can't figure out the best place for this.  
        /* this.problemSet.problems.on("reordered",function () {
                self.announce.addMessage({text: "Problem Set " + self.parent.problemSet.get("set_id") + " was reordered"});
            });  */
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
            $("#show-hide-sets-button i").removeClass("icon-chevron-down").addClass("icon-chevron-up");            
        } else {
            $("#problem-set-list-container").hide("slide", { direction: "up" });
            $("#show-hide-sets-button i").removeClass("icon-chevron-up").addClass("icon-chevron-down");            
        }

    },
    showHWdetails: function(evt){
        if (this.objectDragging) return;
        this.changeView(null,"setDetails", "Set Details");
        this.views.setDetails.changeHWSet($(evt.target).closest(".problem-set").data("setname")); 
        this.headerView.setTemplate(this.views.setDetails.headerInfo).render();

    },
    changeView: function (evt,link,header){
        var linkname = (link)?link:$(evt.target).data("link");
        $(".view-pane").removeClass("active");
        $("#"+linkname).addClass("active");
        $("#viewHeader").html((header)?header:$(evt.target).data("name"));
        this.views[linkname].render();
        this.headerView.setTemplate(this.views[linkname].headerInfo).render();
    },
    // This rerenders the problem set list on the left and sets the drag and drop properties.
    updateProblemSetList: function () {
        var self = this;

        // The following allows a problem set (on the left column to be dragged onto the Calendar)
        $(".problem-set").draggable({   
            revert: true, 
            scroll: false, 
            helper: "clone",
            appendTo: "body",
            cursorAt: {left: 10, top: 10},
            stop: function(evt,ui){
                console.log("in stop");
                console.log(ui)
            },
            start: function(evt,ui){
                console.log(ui);
                console.log(this);
            }
        });

        // allows the problem sets on the left column to accept problems dropped on them. 

        $(".problem-set").droppable({
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
        // When the HW sets are clicked, open the HW details tab.   
        // pstaab: can we include this in the ProblemSetListView?       
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
                console.log("changing the date of a problem set");
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
            problemSet.setDefaultDates(_date).save({success: this.updateCalendar()});
        } else {
            // check first to see if a valid date has been selected. 
            /*if(!moment.unix(problemSet.get("open_date")).isBefore(moment.unix(problemSet.get("due_date")))){
                this.errorPane.addMessage({text: "Oops!!"});
            } */

            problemSet.setDate(type,moment(_date,"YYYY-MM-DD").unix()).save({success: this.updateCalendar()});
        }

    }
});

var HWSettingsView = Backbone.View.extend({
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

var ImportExport = Backbone.View.extend({
    headerInfo: {template: "#importExport-header"},
    initialize: function (){
        _.bindAll(this,"render");
    },
    render: function () {

    }
});

    
    var App = new HomeworkEditorView({el: $("div#mainDiv")});
});
