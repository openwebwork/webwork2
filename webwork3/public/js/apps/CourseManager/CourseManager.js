/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
define(['module','backbone', 'underscore','models/UserList','models/ProblemSetList','models/SettingList',  
    'views/MainViewList',
    'models/AssignmentDate','models/AssignmentDateList','views/WebPage','config','apps/util','jquery-ui','bootstrap'
    ], 
function(module, Backbone, _, UserList, ProblemSetList, SettingList,MainViewList,
    AssignmentDate,AssignmentDateList,WebPage,config,util){
var CourseManager = WebPage.extend({
    tagName: "div",
    initialize: function(){
	    this.constructor.__super__.initialize.apply(this, {el: this.el});
	    _.bindAll(this, 'render', 'setMessages',"showProblemSetDetails",
            "changeView","changeSidebar","loadData","checkData","saveState");  // include all functions that need the this object
	    var self = this;

        this.render();
        this.eventDispatcher = _.clone(Backbone.Events);
        this.session = (module.config().session)? module.config().session : {};
        this.settings = (module.config().settings)? new SettingList(module.config().settings, {parse: true}) : null;
        this.users = (module.config().users) ? new UserList(module.config().users) : null;

        // We need to pass the standard date settings to the problemSets.  
        var dateSettings = util.pluckDateSettings(this.settings);
        this.problemSets = (module.config().sets) ? new ProblemSetList(module.config().sets,{parse: true, 
                dateSettings: dateSettings}) : null;

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

        this.mainViewList.getViewByName("Problem Sets Manager")
            .set({assignmentDates: this.assignmentDateList});

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

    },

    // can a lot of this be handled by the individual views?  

    setMessages: function (){
        var self = this; 

        // This is the way that general messages are handled in the app

        this.eventDispatcher.on({
            "save-state": this.saveState,
            "show-problem-set": this.showProblemSetDetails,
            "add-message": this.messagePane.addMessage,
            "show-help": function() { self.changeSidebar({link: "helpSidepane"})}
        });
    },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
    },
    showProblemSetDetails: function(setName){
        if (this.objectDragging) return;
        this.changeView("Problem Set Details",{});        
        this.mainViewList.getViewByName("Problem Set Details").changeProblemSet(setName).render();
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
});

   
var App = new CourseManager({el: $("div#mainDiv")});
});
