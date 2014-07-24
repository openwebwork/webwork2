/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
define(['module','backbone','views/Sidebar', 'underscore','models/UserList','models/ProblemSetList','models/SettingList',  
    'views/MainViewList', 'models/AssignmentDate','models/AssignmentDateList','views/WebPage',
    'config','apps/util','jquery-ui','bootstrap'], 
function(module, Backbone, Sidebar, _, UserList, ProblemSetList, SettingList,MainViewList,
    AssignmentDate,AssignmentDateList,WebPage,config,util){
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
            "show-problem-set": this.showProblemSetDetails,
            "change-view": function () {
                self.navigationBar.setPaneName(_name);
            }
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
            "change-view": this.changeViewAndSidebar,
            "logout": this.logout,
            "stop-acting": this.stopActing,
            "show-help": function() { self.changeSidebar("Help")},
            "forward-page": function() {self.goForward()},
            "back-page": function() {self.goBack()},
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

    },
    changeViewAndSidebar: function(_view){
        this.changeView(_view);
        this.changeSidebar(this.mainViewList.getDefaultSidebar(_view));
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
    },

    // This ensures that dates selected from date pickers through the interface resets the dates around it 
    // to ensure that are no date errors.  

    setDates: function(model){
        var self = this;

        if(_(model.changed).keys().length>1){
            return;
        }
        // convert all of the dates to Moment objects. 
        var oldUnixDates = model.pick("answer_date","due_date","reduced_scoring_date","open_date")
        var oldMomentDates = _(oldUnixDates).chain().pairs().map(function(date){ return [date[0],moment.unix(date[1])];}).object().value();
        // make sure that the dates are in integer form. 
        oldUnixDates = _(oldMomentDates).chain().pairs().map(function(date) { return [date[0],date[1].unix()]}).object().value();
        var newMomentDates = _(oldUnixDates).chain().pairs().map(function(date){ return [date[0],moment.unix(date[1])];}).object().value();

        if(model.changed["due_date"]){
            if(oldMomentDates.due_date.isBefore(oldMomentDates.open_date)){
                newMomentDates.open_date = moment(oldMomentDates.due_date);
            }
            if(oldMomentDates.due_date.isBefore(oldMomentDates.reduced_scoring_date)){
                var oldDueDate = moment(oldMomentDates.due_date);
                newMomentDates.reduced_scoring_date = oldDueDate.subtract("minutes",
                        self.settings.getSettingValue("pg{ansEvalDefaults}{reducedScoringPeriod}"));
                if(newMomentDates.open_date.isAfter(newMomentDates.reduced_scoring_date)){
                    newMomentDates.open_date = moment(newMomentDates.reduced_scoring_date);
                }
            }
            if(oldMomentDates.answer_date.isBefore(oldMomentDates.due_date)){
                newMomentDates.answer_date = moment(newMomentDates.due_date);
            }
        }

        if(model.changed["open_date"]){
            if(oldMomentDates.open_date.isAfter(oldMomentDates.reduced_scoring_date)){
                newMomentDates.reduced_scoring_date = moment(oldMomentDates.open_date);

                if(newMomentDates.reduced_scoring_date.isAfter(newMomentDates.due_date)){
                    var oldRSDate = moment(newMomentDates.reduced_scoring_date);
                    newMomentDates.due_date = oldRSDate.add("minutes",
                        self.settings.getSettingValue("pg{ansEvalDefaults}{reducedScoringPeriod}"));
                }
            }
            if(oldMomentDates.answer_date.isBefore(newMomentDates.due_date)){
                newMomentDates.answer_date = moment(newMomentDates.due_date);
            }
        }

        if(model.changed["reduced_scoring_date"]){
            if(oldMomentDates.reduced_scoring_date.isBefore(oldMomentDates.open_date)){
                newMomentDates.open_date = moment(oldMomentDates.reduced_scoring_date);
            }

            if(oldMomentDates.reduced_scoring_date.isAfter(oldMomentDates.due_date)){
                var oldRSDate = moment(oldMomentDates.reduced_scoring_date);
                newMomentDates.due_date = oldRSDate.add("minutes",
                        self.settings.getSettingValue("pg{ansEvalDefaults}{reducedScoringPeriod}"));
            }

            if(newMomentDates.due_date.isAfter(oldMomentDates.answer_date)){
                newMomentDates.answer_date = moment(newMomentDates.due_date);
            }
        }

        if(model.changed["answer_date"]){

            if(oldMomentDates.answer_date.isBefore(oldMomentDates.due_date)){
                newMomentDates.due_date = moment(oldMomentDates.answer_date);
            }
            if(oldMomentDates.answer_date.isBefore(oldMomentDates.reduced_scoring_date)){
                var newDueDate = moment(newMomentDates.due_date);
                newMomentDates.reduced_scoring_date = newDueDate.subtract("minutes",
                    self.settings.getSettingValue("pg{ansEvalDefaults}{reducedScoringPeriod}"));
            }
            if(oldMomentDates.answer_date.isBefore(oldMomentDates.open_date)){
                newMomentDates.open_date = moment(newMomentDates.reduced_scoring_date);
            }

        }


        // convert the moments back to unix time
        var newUnixDates = _(newMomentDates).chain().pairs().map(function(date) { 
                    return [date[0],date[1].unix()]}).object().value();
        if(! _.isEqual(oldUnixDates,newUnixDates)){

            model.set(newUnixDates);
        }
    }

});

   
var App = new CourseManager({el: $("div#mainDiv")});
});
