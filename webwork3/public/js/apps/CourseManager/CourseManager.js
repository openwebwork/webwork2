/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
define(['module','backbone','views/Sidebar', 'underscore','models/UserList','models/ProblemSetList','models/SettingList',  
    'views/MainViewList', 'models/AssignmentDate','models/AssignmentDateList','views/WebPage', 'moment',
    'config','apps/util','jquery-ui','bootstrap'], 
function(module, Backbone, Sidebar, _, UserList, ProblemSetList, SettingList,MainViewList,
    AssignmentDate,AssignmentDateList,WebPage,moment,config,util){
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
        // We need to pass the standard date settings to the problemSets.  
        var dateSettings = util.pluckDateSettings(this.settings);
        this.problemSets = (module.config().sets) ? new ProblemSetList(module.config().sets,{parse: true, 
                dateSettings: dateSettings}) : null;

        _.extend(config.courseSettings,{course_id: module.config().course_id,user: this.session.user});
        if(this.session.user&&this.session.logged_in==1){
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
        
        // put all of the dates in the problem sets in a better data structure for calendar rendering.
        this.buildAssignmentDates();
        this.setMainViewList(new MainViewList({settings: this.settings, users: this.users, 
                problemSets: this.problemSets, eventDispatcher: this.eventDispatcher}));
        

        // set up some of the main views with additional information.
        
        this.mainViewList.getView("calendar")
            .set({assignmentDates: this.assignmentDateList, viewType: "instructor", calendarType: "month"})
            .on("calendar-change",self.updateCalendar);

        this.mainViewList.getView("problemSetsManager").set({assignmentDates: this.assignmentDateList});
        this.mainViewList.getSidebar("allMessages").set({messages: this.messagePane.messages});
        this.mainViewList.getSidebar("help").parent = this;
        
        this.postInitialize();
        
        // can't we just pull this from the settings when needed.  Why do we need another variable. 
        config.timezone = this.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    
        // this will automatically save (sync) any change made to a problem set.
        this.problemSets.on("change",function(_set){
            _set.save();
        })        

        // The following is useful in many different views, so is defined here. 
        // It adjusts dates to ensure that they aren't illegal.

        this.problemSets.on("change:due_date change:reduced_scoring_date change:open_date change:answer_date",this.setDates);
                
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

        this.navigationBar.$(".manager-menu").append("<li class='ww2-link'><a href='/webwork2/"+config.courseSettings.course_id+"''>WeBWorK2</a></li>");
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
            if(parseInt(_set.get("reduced_scoring_date"))>0) {
                self.assignmentDateList.add(new AssignmentDate({type: "reduced-scoring", problemSet: _set,
                    date: moment.unix(_set.get("reduced_scoring_date")).format("YYYY-MM-DD")}) );
            }
        });
    }

});

   
var App = new CourseManager({el: $("div#mainDiv")});
});
