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
    messageTemplate: _.template($("#course-manager-messages-template").html()),
    initialize: function(){
        WebPage.prototype.initialize.apply(this,{el: this.el});
	    _.bindAll(this, 'render', 'setMessages',"showProblemSetDetails","openCloseSidebar","stopActing",
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
            this.loginPane.$(".message-bottom").html(this.messageTemplate({type: "loading_data"}))
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
            this.loginPane.$(".message").html(this.messageTemplate({type: "bad_password"}));
        }
    },
    // wait for all of the data to get loaded in, close the login window, then start the Course Manager. 
    checkData: function(name) {
        this.data_loaded[name] = true;
        console.log(_(this.data_loaded).chain().values().every(_.identity).value());
        if(_(this.data_loaded).chain().values().every(_.identity).value()){
            this.closeLogin();

            // make sure the dateSettings are properly stored:
            this.problemSets.dateSettings = util.pluckDateSettings(this.settings);

            this.startManager();
        }
    },
    startManager: function () {
        var self = this;
        this.navigationBar.setLoginName(this.session.user);
        this.currentSidePane = {};
        
        this.mainViewList = new MainViewList({settings: this.settings, users: this.users, 
                problemSets: this.problemSets, eventDispatcher: this.eventDispatcher});

        this.buildAssignmentDates();

        // Build the menu.  Should we make a View for this?  

        var menuItemTemplate = _.template($("#main-menu-item-template").html());
        var ul = $("#menu-navbar-collapse .manager-menu");
        _(this.mainViewList.viewInfo.main_views).each(function(item){
            ul.append(menuItemTemplate({name: item.name}));
        })

        // can't we just pull this from the settings when needed.  Why do we need another variable. 
        config.timezone = this.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    
        _(this.views).chain().keys().each(function(key){ self.views[key].setParentView(self)});


        this.mainViewList.getViewByName("Calendar")
            .set({assignmentDates: this.assignmentDateList, viewType: "instructor", calendarType: "month"})
            .dispatcher.on("calendar-change",self.updateCalendar);

        this.mainViewList.getViewByName("Problem Sets Manager")
            .set({assignmentDates: this.assignmentDateList});

        // Define all of the option views available for the right side
        // 

        this.mainViewList.getSidepaneByName("All Messages")
            .set({messages: this.messagePane.messages});


        // Build the options menu.  Should we make a View for this?  

        var menuItemTemplate = _.template($("#main-menu-item-template").html());
        var ul = this.$(".sidebar-menu .dropdown-menu");
        _(this.mainViewList.viewInfo.sidepanes).each(function(item){
            ul.append(menuItemTemplate({name: item.name}));
        })



        this.setMessages();  

        // this will automatically save (sync) any change made to a problem set.
        this.problemSets.on("change",function(_set){
            _set.save();
        })        

        // load the previous state of the app or set it to the Calendar
        var state = this.loadState();

        if(state){
            this.changeView(state.view,state);
        } else {
            this.changeView("Calendar",{});    
        }        

        this.navigationBar.on({
            "change-view": this.changeView,
            "logout": this.logout,
            "stop-acting": this.stopActing
        });

        this.users.on({"act_as_user": function(model){
            self.session.effectiveUser = model.get("user_id");
            $.ajax({method: "POST", 
                url: config.urlPrefix+"courses/"+config.courseSettings.course_id+"/session", 
                data: {effectiveUser: self.session.effectiveUser},
                success: function () {
                    self.navigationBar.setActAsName(self.session.effectiveUser);                    
                }
            });
        }});

        $(window).on("beforeunload", function () {
            return self.messageTemplate({type: "leave_page"});
         }).on("resize",function(){ // if the window is resized, rerender the view and sidepane
            self.currentView.render();
            if(self.currentSidePane.sidePane){
                self.currentSidePane.sidePane.render();
            }
         })

        // Add a link to WW2 via the main menu.

        this.navigationBar.$(".manager-menu").append("<li><a href='/webwork2/"+config.courseSettings.course_id+"''>WeBWorK2</a></li>");
        this.delegateEvents();
    },
    events: {
        "click .sidebar-menu a.link": "changeSidebar"
    },

    // can a lot of this be handled by the individual views?  

    setMessages: function (){
        var self = this; 

        // This is the way that general messages are handled in the app

        this.eventDispatcher.on({
            "save-state": this.saveState,
            "show-problem-set": this.showProblemSetDetails,
            "add-message": this.messagePane.addMessage,
            "show-help": function() { self.changeSidebar({link: "helpSidepane"})},
            "open-close-sidebar": this.openCloseSidebar
        });
    },
    render: function(){
        WebPage.prototype.render.apply(this);  // Call  WebPage.render();
    },
    showProblemSetDetails: function(setName){
        if (this.objectDragging) return;
        this.changeView("Problem Set Details",{});        
        this.mainViewList.getViewByName("Problem Set Details").changeProblemSet(setName).render();
    },
    openCloseSidebar: function (str) {
        if(this.currentSidePane.isOpen || str === "open"){
            this.currentSidePane.isOpen = false;
            $("#sidebar-container").removeClass("hidden");
            $("#main-view").removeClass("col-md-12").addClass("col-md-9");
            self.$(".open-close-view i").removeClass("fa-chevron-left").addClass("fa-chevron-right");
        } else if (! this.currentSidePane.isOpen || str === "close"){
            this.currentSidePane.isOpen = true;
            $("#sidebar-container").addClass("hidden");
            $("#main-view").removeClass("col-md-9").addClass("col-md-12"); 
            self.$(".open-close-view i").removeClass("fa-chevron-right").addClass("fa-chevron-left");
        }
    },
    changeSidebar: function(_name){
        var name = _.isString(_name) ? _name : $(_name.target).data("name");
        if(this.currentSidePane && this.currentSidePane.sidePane){
            this.currentSidePane.sidePane.remove();
        }
        if ((name==="")){
            this.openCloseSidebar("close");
            return;
        }
        this.currentSidePane.sidePane = this.mainViewList.getSidepaneByName(name);
        if(this.currentSidePane.sidePane){
            this.$(".sidebar-menu .sidebar-name").text(name);
            if (! $("#sidebar-container .sidebar-content").length){
                $("#sidebar-container").append("<div class='sidebar-content'></div>");
            }
            this.currentSidePane.sidePane.setMainView(this.currentView)
                .setElement(this.$(".sidebar-content")).render();
        }    
        this.currentView.setSidePane(this.currentSidePane.sidePane);
        this.openCloseSidebar("open");
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
    },
    saveState: function() {
        var state = this.currentView.getState();
        state.view = this.currentView.viewName;
        window.localStorage.setItem("ww3_cm_state",JSON.stringify(state));
    },
    loadState: function () {
        return JSON.parse(window.localStorage.getItem("ww3_cm_state"));
    },
    logout: function(){
        var conf = confirm("Do you want to log out?");
        if(conf){
            $.ajax({method: "POST", 
                url: config.urlPrefix+"courses/"+config.courseSettings.course_id+"/logout", 
                success: function () {
                    location.href="/webwork2";
                }
            });
        }
        console.log("time to log out");
    },
    stopActing: function (){
        var self = this;
        this.session.effectiveUser = this.session.user;
        $.ajax({method: "POST", 
            url: config.urlPrefix+"courses/"+config.courseSettings.course_id+"/session", 
            data: {effectiveUser: self.session.effectiveUser},
            success: function () {
                self.navigationBar.setActAsName("");                    
            }
        });

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
