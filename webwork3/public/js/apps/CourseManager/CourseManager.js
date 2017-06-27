/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....

*/
define(['module','backbone','views/Sidebar', 'underscore','views/WebPage',
    'models/UserList','models/ProblemSetList','models/SettingList',
    'views/MainViewList', 'models/AssignmentDate','models/AssignmentDateList',
    'models/User', 'moment',
    'config','apps/util','jquery-ui','bootstrap'],
function(module, Backbone, Sidebar, _,WebPage, UserList, ProblemSetList,
    SettingList,MainViewList,AssignmentDate,AssignmentDateList,User,
    moment,config,util){
var CourseManager = WebPage.extend({
    messageTemplate: _.template($("#course-manager-messages-template").html()),
    initialize: function(){
        WebPage.prototype.initialize.apply(this,{el: this.el});
        _(this).bindAll("showProblemSetDetails","changeViewAndSidebar","stopActing","logout");
	    var self = this;

        this.render();
        this.session = (module.config().session)? module.config().session : {};
        this.settings = (module.config().settings)? new SettingList(module.config().settings, {parse: true}) : null;
        this.users = (module.config().users) ? new UserList(module.config().users) : null;
        this.user_info = (module.config().user_info) ? new User(module.config().user_info): null;
        // We need to pass the standard date settings to the problemSets.
        var dateSettings = util.pluckDateSettings(this.settings);
        this.problemSets = (module.config().sets) ? new ProblemSetList(module.config().sets,{parse: true,
                dateSettings: dateSettings}) : null;

        _.extend(config.courseSettings,{course_id: module.config().course_id,user: this.session.user});
        if(this.session.user_id&&this.session.logged_in==1){
            this.startManager();
        } else {
            this.requestLogin({success: function (data) {
                    // save the new session key and reload the page.
                    self.session.key = data.session_key;
                    window.location.reload();
                }
            });
        }

        $(document).ajaxError(function (e, xhr, options, error) {
            if(xhr.status==419){
                self.requestLogin({success: function(){
                    self.loginPane.close();
                }});
            }
        });

        // This is the way that general messages are handled in the app

        this.eventDispatcher.on({
                "show-problem-set": this.showProblemSetDetails
        });


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

        this.setMainViewList(new MainViewList({settings: this.settings, users: this.users,
                problemSets: this.problemSets, eventDispatcher: this.eventDispatcher}));


        // set up some of the main views with additional information.

        this.mainViewList.getView("calendar").set({viewType: "instructor", calendarType: "month"})
            .on("calendar-change",self.updateCalendar);

        this.mainViewList.getView("problemSetsManager").set({assignmentDates: this.assignmentDateList});
        this.mainViewList.getView("userSettings").set({user_info: this.user_info});
        this.mainViewList.getSidebar("allMessages").set({messages: this.messagePane.messages});
        this.mainViewList.getSidebar("help").parent = this;

        this.postInitialize();

        // not sure why this is needed.
        //config.timezone = this.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");

        this.navigationBar.on({
            "stop-acting": this.stopActing,
        });

        this.users.on({"act_as_user": function(model){
            self.session.effectiveUser = model.get("user_id");
            $.ajax({method: "POST",
                url: config.urlPrefix+"courses/"+config.courseSettings.course_id+"/session",
                data: {effectiveUser: self.session.effectiveUser},
                success: function () {
                    self.navigationBar.setActAsName(self.session.effectiveUser);
                    // update the WW2 link
                    var obj = {
                        effectiveUser: self.session.effectiveUser,
                        user: self.session.user,
                        key: self.session.key
                    };
                    $(".ww2-link").children("a").attr("href","/webwork2/" + config.courseSettings.course_id+"?"+$.param(obj));
                }
            });
        }});


        // Add a link to WW2 via the main menu.

        this.navigationBar.$(".manager-menu").append("<li class='ww2-link'>"+
            "<a href='/webwork2/"+config.courseSettings.course_id+"''><span class='wwlogo'>W</span>WeBWorK2</a></li>");
        this.delegateEvents();


    },
    // move this to WebPage.js  (need to deal with the parent-child events)
    events: {
        "click .sidebar-menu a.link": "changeSidebar"
    },
    showProblemSetDetails: function(setName){
        if (this.objectDragging) return;
        this.changeView("problemSetDetails",{set_id: setName});
        this.changeSidebar("problemSets",{});
        this.saveState();
    },
    changeViewAndSidebar: function(_view){
        this.changeView(_view,this.mainViewList.getView(_view).getDefaultState());
        this.changeSidebar(this.mainViewList.getDefaultSidebar(_view),{is_open: true});
        this.saveState();
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

    }

});


var App = new CourseManager({el: $("div#mainDiv")});
});
