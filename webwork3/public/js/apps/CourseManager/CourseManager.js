/*  HomeworkManager.js:
   This is the base javascript code for the Homework Manager.  This sets up the View and ....
  
*/
define(['module','backbone','views/SidePane', 'underscore','models/UserList','models/ProblemSetList','models/SettingList',  
    'views/MainViewList', 'models/AssignmentDate','models/AssignmentDateList','views/WebPage',
    'config','apps/util','jquery-ui','bootstrap'], 
function(module, Backbone, SidePane, _, UserList, ProblemSetList, SettingList,MainViewList,
    AssignmentDate,AssignmentDateList,WebPage,config,util){
var CourseManager = WebPage.extend({
    messageTemplate: _.template($("#course-manager-messages-template").html()),
    initialize: function(){
        WebPage.prototype.initialize.apply(this,{el: this.el});
	    _.bindAll(this, 'render', 'setMessages',"showProblemSetDetails","openCloseSidePane","stopActing",
            "changeView","changeSidePane","loadData","checkData","saveState","logout","setDates");  // include all functions that need the this object
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
        if(this.session.user&&this.session.logged_in==1){
            this.startManager();
        } else {
            this.requestLogin({success: function (data) {
                // save the new session key and reload the page.  
                self.session.key = data.session_key;
                window.location.reload();
                /*window.location.href=config.urlPrefix+"courses/"+config.courseSettings.course_id+"/manager?"
                    + $.param(_(self.session).pick("user","key")); */
            }});

            //    this.loadData
            //});
        }

        $(document).ajaxError(function (e, xhr, options, error) {
            if(xhr.status==419){
                self.requestLogin({success: function(){
                    self.loginPane.close();
                }});
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
        this.currentSidePane = {};
        
        this.mainViewList = new MainViewList({settings: this.settings, users: this.users, 
                problemSets: this.problemSets, eventDispatcher: this.eventDispatcher});

        this.buildAssignmentDates();

        // Build the menu.  Should we make a View for this?  

        var menuItemTemplate = _.template($("#main-menu-item-template").html());
        var ul = $(".manager-menu");
        _(this.mainViewList.viewInfo.main_views).each(function(item){
            ul.append(menuItemTemplate({name: item.name}));
            item.other_sidepanes[item.other_sidepanes.length] = "Help";
            item.other_sidepanes[item.other_sidepanes.length] = "All Messages";
        })

        // can't we just pull this from the settings when needed.  Why do we need another variable. 
        config.timezone = this.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
    
        _(this.views).chain().keys().each(function(key){ self.views[key].setParentView(self)});


        this.mainViewList.getViewByName("Calendar")
            .set({assignmentDates: this.assignmentDateList, viewType: "instructor", calendarType: "month"})
            .on("calendar-change",self.updateCalendar);

        this.mainViewList.getViewByName("Problem Sets Manager")
            .set({assignmentDates: this.assignmentDateList});


        this.mainViewList.getSidepaneByName("All Messages")
            .set({messages: this.messagePane.messages});


        // Build the options menu.  Should we make a View for this?  

        this.setMessages();  

        // this will automatically save (sync) any change made to a problem set.
        this.problemSets.on("change",function(_set){
            _set.save();
        })        

        // load the previous state of the app or set it to the Calendar
        this.appState = this.loadState();

        if(this.appState && typeof(this.appState)!=="undefined" && 
                this.appState.states && typeof(this.appState.states)!=="undefined" && 
                typeof(this.appState.index)!=="undefined"){
            this.changeView(this.appState.states[this.appState.index].view,this.appState.states[this.appState.index]);            
        } else {
            this.appState = {index: void 0, states: []};
            this.changeView("Calendar",{});    
        }        

        // The following is useful in many different views, so is defined here. 
        // It adjusts dates to ensure that they aren't illegal.

        this.problemSets.on("change:due_date change:reduced_scoring_date change:open_date change:answer_date",this.setDates);
                
        this.navigationBar.on({
            "change-view": this.changeView,
            "logout": this.logout,
            "stop-acting": this.stopActing,
            "show-help": function() { self.changeSidePane("Help")},
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

        // this ensures that the rerender call on resizing the window only occurs once every 500 ms.  

        var renderMainPane = _.debounce(function(evt){ 
            self.currentView.render();
            if(self.currentSidePane && self.currentSidePane.sidePane){
                self.currentSidePane.sidePane.render();
            }
        },500);

        $(window).on("resize",renderMainPane);

        // Add a link to WW2 via the main menu.

        this.navigationBar.$(".manager-menu").append("<li class='ww2-link'><a href='/webwork2/"+config.courseSettings.course_id+"''>WeBWorK2</a></li>");
        this.delegateEvents();
    },
    events: {
        "click .sidepane-menu a.link": "changeSidePane"
    },

    // can a lot of this be handled by the individual views?  

    setMessages: function (){
        var self = this; 

        // This is the way that general messages are handled in the app

        this.eventDispatcher.on({
            "save-state": this.saveState,
            "show-problem-set": this.showProblemSetDetails,
            "add-message": this.messagePane.addMessage,
            "open-close-sidepane": this.openCloseSidePane
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
    openSidePane: function (){
        this.currentSidePane.isOpen = true;
        $("#sidepane-container").removeClass("hidden");
        $("#main-view").removeClass("col-md-12").addClass("col-md-9");
        self.$(".open-close-view i").removeClass("fa-chevron-left").addClass("fa-chevron-right");
        if(this.currentSidePane && (typeof(this.currentSidePane.sidePane)==="undefined" ||
             !(this.currentSidePane.sidePane instanceof SidePane))) {
                this.changeSidePane(this.mainViewList.getOtherSidepanes(this.currentView.viewName)[0]);
        }
        this.currentSidePane.sidePane.render();
    },
    closeSidePane: function (){
        this.currentSidePane.isOpen = false;
        $("#sidepane-container").addClass("hidden");
        $("#main-view").removeClass("col-md-9").addClass("col-md-12"); 
        self.$(".open-close-view i").removeClass("fa-chevron-right").addClass("fa-chevron-left");
    },
    openCloseSidePane: function (str) {
        if(str==="close"){
            this.closeSidePane();
        } else if (str==="open"){
            this.openSidePane();
        } else if (this.currentSidePane.isOpen) {
            this.closeSidePane();
        } else if (! this.currentSidePane.isOpen){
            this.openSidePane();
        }
    },
    changeSidePane: function(_name){
        var name = _.isString(_name) ? _name : $(_name.target).data("name");
        if(this.currentSidePane && this.currentSidePane.sidePane){
            this.currentSidePane.sidePane.remove();
        }
        var mainViewInfo = _(this.mainViewList.views).findWhere({name: this.currentView.viewName});
        if ((name==="")){
            this.openCloseSidePane("close");
            return;
        }
        this.currentSidePane.sidePane = this.mainViewList.getSidepaneByName(name);

        if(this.currentSidePane.sidePane){
            this.$(".sidepane-menu .sidepane-name").text(name);
            if (! $("#sidepane-container .sidepane-content").length){
                $("#sidepane-container").append("<div class='sidepane-content'></div>");
            }
            this.currentSidePane.sidePane.setMainView(this.currentView)
                .setElement(this.$(".sidepane-content")).render();

            // set the side pane options for the main view

            var menuItemTemplate = _.template($("#main-menu-item-template").html());
            var ul = this.$(".sidepane-menu .dropdown-menu").empty();
            _(mainViewInfo.other_sidepanes).each(function(_name){
                ul.append(menuItemTemplate({name: _name}));
            })



        }
        this.currentView.setSidePane(this.currentSidePane.sidePane);
        this.openCloseSidePane("open");
    },
    changeView: function (_name,state){
        var defaultSidePane; 
        if(this.currentView){
            // destroy any popovers on the view
            $('[data-toggle="popover"]').popover("destroy")
            this.currentView.remove();
        }
        $("#main-view").html("<div class='main'></div>");
        this.navigationBar.setPaneName(_name);
        this.currentView = this.mainViewList.getViewByName(_name);
        if(typeof(this.currentView)==="undefined"){
            this.currentView = this.mainViewList.getViewByName("Calendar");
            defaultSidePane = _(this.mainViewList.viewInfo.main_views).findWhere({name: "Calendar"}).default_sidepane;
        } 
        if(typeof(this.defaultSidepane)==="undefined"){
            defaultSidepane = _(this.mainViewList.viewInfo.main_views).findWhere({name: this.currentView.viewName}).default_sidepane;
        }
        this.currentView.setElement(this.$(".main")).setState(state).render();
        this.changeSidePane(defaultSidepane);
        this.saveState();
    },
    /***
     * 
     * The following save the current state of the interface
     *
     *  {
     *      main_view: "name_of_current_view",
     *      main_view_state: {} an object returned from the view
     *      sidebar: "name_of_sidebar",
     *      sidebar_state: {}  an object returned from the sidebar
     *  }
     *
     *  The entire state corresponds to an array of states as described above and an index on 
     *  the current state that you are in.  
     *
     *  Travelling forward and backwards in the array is how the forward/back works. 
     *
     ***/


    saveState: function() {
        if(!this.currentView){
            return;
        }
        
        var state = {
            main_view: this.currentView.name, 
            main_view_state: this.currentView.getState(),
            sidebar: this.currentView.optionPane.name,
            sidebar_state: this.currentView.optionPane.getState()
        };

        
        if(typeof(this.appState.index) !== "undefined"){
            if(this.appState.states[this.appState.index].main_view === state.main_view){
                this.appState.states[this.appState.index] = state;
            } else {
                this.appState.index++;
                this.appState.states[this.appState.index]=state;
                this.appState.states.splice(this.appState.index+1,Number.MAX_VALUE); // delete the end of the states array. 
            }
        } else {
            this.appState.index = 0;
            this.appState.states = [state];
        }
        window.localStorage.setItem("ww3_cm_state",JSON.stringify(this.appState));
        // change the navigation button states
        if(this.appState.index>0){
            this.navigationBar.$(".back-button").removeAttr("disabled")
        } else {
            this.navigationBar.$(".back-button").attr("disabled","disabled");
        }
        if(this.appState.index<this.appState.states.length-1){
            this.navigationBar.$(".forward-button").removeAttr("disabled")
        } else {
            this.navigationBar.$(".forward-button").attr("disabled","disabled");
        }
    },
    loadState: function () {
        return JSON.parse(window.localStorage.getItem("ww3_cm_state"));
    },
    goBack: function () {
        this.appState.index--;
        this.changeView(this.appState.states[this.appState.index].view,this.appState.states[this.appState.index]);            
    },
    goForward: function () {
        this.appState.index++;
        this.changeView(this.appState.states[this.appState.index].view,this.appState.states[this.appState.index]);            
    },
    logout: function(){
        var self = this;
        var conf = confirm("Do you want to log out?");
        if(conf){
            $.ajax({method: "POST", 
                url: config.urlPrefix+"courses/"+config.courseSettings.course_id+"/logout", 
                success: function (data) {
                    self.session.logged_in = data.logged_in;
                    location.href="/webwork2";
                }
            });
        }
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
