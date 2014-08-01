define(['backbone','views/MessageListView','views/ModalView','config','views/NavigationBar','views/Sidebar'], 
function(Backbone,MessageListView,ModalView,config,NavigationBar,Sidebar){
	var WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    messageTemplate: _.template($("#general-messages").html()),
    initialize: function (options) {
        var self = this;
    	_.bindAll(this,"closeLogin","openSidebar","closeSidebar","changeSidebar","changeView"
                        ,"saveState");
        this.currentView = void 0;
        this.currentSidebar = void 0;

        this.messagePane = new MessageListView();
        this.loginPane = new LoginView({messageTemplate: this.messageTemplate});

        this.eventDispatcher = _.clone(Backbone.Events);
        this.eventDispatcher.on({
            "save-state": this.saveState,
            "add-message": this.messagePane.addMessage,
            "open-sidebar": this.openSidebar,
            "close-sidebar": this.closeSidebar,
            "show-help": function() { self.changeSidebar("help")},
        });

    },
    setMainViewList: function(_list){
        this.mainViewList = _list;
    },
    postInitialize: function () {
        var self = this;
        // load the previous state of the app or set it to the first main_view
        this.appState = JSON.parse(window.localStorage.getItem("ww3_cm_state"));

        if(this.appState && typeof(this.appState)!=="undefined" && 
                this.appState.states && typeof(this.appState.states)!=="undefined" && 
                typeof(this.appState.index)!=="undefined"){
            this.updateViewAndSidebar({save_state: false});
        } else {
            this.appState = {index: void 0, states: []};
            this.changeView(this.mainViewList.views[0].info.id,{});
            var _sidebarID = this.mainViewList.getDefaultSidebar(this.currentView.info.id);
            this.changeSidebar(_sidebarID,{is_open: true});
            this.saveState();
        }
        this.enableBackForwardButtons();

        // build the menu

        var menuItemTemplate = _.template($("#main-menu-item-template").html());
        var ul = $(".manager-menu");
        _(this.mainViewList.views).each(function(_view){
            ul.append(menuItemTemplate({name: _view.info.name, id: _view.info.id,icon: _view.info.icon}));
        });

        // this ensures that the rerender call on resizing the window only occurs once every 500 ms.  

        var renderMainPane = _.debounce(function(evt){ 
            self.currentView.render();
            if(self.currentSidebar){
                self.currentSidebar.render();
            }
        },250);

        $(window).on("resize",renderMainPane);


        this.navigationBar.on({
            "change-view": function(id) {
                self.changeView(id,self.mainViewList.getView(id).getDefaultState());
                self.changeSidebar(self.mainViewList.getView(id).info.default_sidebar,{is_open: true});
                self.currentView.sidebar = self.currentSidebar;
                self.saveState();
            },
            "logout": this.logout,
            "show-help": function() { self.changeSidebar("help",{is_open: true})},
            "forward-page": function() {self.goForward()},
            "back-page": function() {self.goBack()},
        });
        
    },
    render: function () {
    	var self = this; 

        // I don't think we're using this anymore. 
        //this.$el.prepend(this.messagePane.render().el);
        this.navigationBar = new NavigationBar({el: $(".navbar-fixed-top")}).render();
    },
    closeLogin: function () {
        this.loginPane.close();
    },
    requestLogin: function (opts){
        this.loginPane.loginOptions = opts;
        this.loginPane.render().open();

    },
    setLoginTemplate: function(opts){
        this.loginPane.set(opts);
    },
    openSidebar: function (){
        if(! this.currentSidebar){
            var otherSidebars = this.mainViewList.getOtherSidebars(this.currentView.info.id);
            if(otherSidebars[0]){ 
                this.changeSidebar([0]);
            } else {
                this.changeSidebar("help",{is_open: true});
            }
            return;
        }
        this.currentSidebar.state.set("is_open",true);
        this.currentSidebar.$el.parent().removeClass("hidden");
        this.currentView.$el.parent().removeClass("col-md-12").addClass("col-md-9");
        this.$(".close-view-button").removeClass("hidden");
        this.$(".open-view-button").addClass("hidden");
        this.currentSidebar.render();
    },
    closeSidebar: function (){
        if(this.currentSidebar){
            this.currentSidebar.state.set("is_open",false);    
        }
        $("#sidebar-container").addClass("hidden");
        $("#main-view").removeClass("col-md-9").addClass("col-md-12"); 
        this.$(".open-view-button").removeClass("hidden");
        this.$(".close-view-button").addClass("hidden");

    },
    changeSidebar: function(arg,_state){
        var id, set_sidebar_to_open, self = this;
        if(this.currentSidebar){
            this.currentSidebar.remove();
        }

        if(_.isString(arg)) { 
            id = arg;
        } else if(arg instanceof Sidebar){
            id = arg.info.id;
        } else if (_.isObject(arg)){
            id = $(arg.target).data("id");
            set_sidebar_to_open = true; // this is used to make sure the sidebar opens on changing the view.
                                        // seems like there could be a cleaner way to do this.
        }

        if (id==="" || typeof(id)==="undefined"){
            this.currentSidebar = null;
            this.closeSidebar();
            return;
        }

        this.currentSidebar = this.mainViewList.getSidebar(id);
        if(_state){
            this.currentSidebar.state.set(_state);
        }

        // for all views, don't listen to sidebar events:
        _(this.mainViewList.views).each(function(view){
            view.stopListening(this.currentSidebar);
        });
        // then register sidebar events for this view
        _(this.currentView.sidebarEvents).chain().keys().each(function(event){
            self.currentView.listenTo(self.currentSidebar,event,self.currentView.sidebarEvents[event]);
        });


        // set up the possible options and render the sidebar

        this.$(".sidebar-menu .sidebar-name").text(this.currentSidebar.info.name);
        if (! $("#sidebar-container .sidebar-content").length){
            $("#sidebar-container").append("<div class='sidebar-content'></div>");
        }
        this.currentSidebar.setElement(this.$(".sidebar-content")).render();

        // set the side pane options for the main view

        var menuItemTemplate = _.template($("#main-menu-item-template").html());
        var ul = this.$(".sidebar-menu .dropdown-menu").empty();
        _(this.mainViewList.getOtherSidebars(this.currentView.info.id)).each(function(_id){
            ul.append(menuItemTemplate({id: _id, name: self.mainViewList.getSidebar(_id).info.name}));
        });
        _(this.mainViewList.getCommonSidebars()).each(function(_id){
            ul.append(menuItemTemplate({id: _id, name: self.mainViewList.getSidebar(_id).info.name}));
        });
        this.currentView.sidebar = this.currentSidebar;

        if(this.currentSidebar.state.get("is_open") || set_sidebar_to_open){
            this.openSidebar();            
        } else {
            this.closeSidebar();
        }
    },
    changeView: function (_id,state){ 
        if(_id){
            // destroy any popovers on the view
            $('[data-toggle="popover"]').popover("destroy")
            if(this.currentView){
                this.currentView.remove();
            }
            this.currentView = this.mainViewList.getView(_id);
        } else {
            this.currentView = this.mainViewList.views[0];
        }
        $("#main-view").html("<div class='main'></div>");
        this.navigationBar.setPaneName(this.currentView.info.name);
        
        this.currentView.setElement(this.$(".main")).setState(state).render();
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
     *  Traveling forward and backwards in the array is how the forward/back works. 
     *
     ***/
    saveState: function() {
        if(!this.currentView){
            return;
        }
        
        var state = {
            main_view: this.currentView.info.id, 
            main_view_state: this.currentView.getState(),
            sidebar: this.currentSidebar ? this.currentSidebar.info.id: "",
            sidebar_state: this.currentSidebar? this.currentSidebar.getState() : {},
            sidebar_open: this.currentSidebar ? this.currentSidebar.getState().is_open : false
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
        this.enableBackForwardButtons();
    },
    enableBackForwardButtons: function () {  // change the navigation button states
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
    goBack: function () {
        this.appState.index--;
        this.updateViewAndSidebar({save_state: true});
    },
    goForward: function () {
        this.appState.index++;
        this.updateViewAndSidebar({save_state: true});
    },
    updateViewAndSidebar: function (options) {
        var currentState = this.appState.states[this.appState.index];
        this.changeView(currentState.main_view,currentState.main_view_state);
        this.changeSidebar(currentState.sidebar,_.extend(currentState.sidebar_state,{is_open: currentState.sidebar_open}));
        this.currentView.sidebar = this.currentSidebar;
        if(options.save_state){
            this.saveState();            
        }
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


});

var LoginView = ModalView.extend({
    initialize: function (options) {
        _.bindAll(this,"login");
        var tempOptions = _.extend(options || {} , {template: $("#login-template").html(), 
                        templateOptions: {message: options.messageTemplate({type: "relogin"})},
                        buttons: {text: "Login", click: this.login}});
        this.constructor.__super__.initialize.apply(this,[tempOptions]);
    },
    render: function () {
        this.constructor.__super__.render.apply(this); 
        return this;
    },
    login: function (options) {
        var loginData = {user: this.$(".login-name").val(), password: this.$(".login-password").val()};
        $.ajax({url: config.urlPrefix + "courses/" + config.courseSettings.course_id + "/login",
                data: loginData,
                type: "POST",
                success: this.loginOptions.success});
    }

});


return WebPage;
});