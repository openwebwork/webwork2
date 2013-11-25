define(['Backbone','views/MessageListView','views/ModalView','config', 'jquery-truncate'], 
function(Backbone,MessageListView,ModalView,config){
	var WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    initialize: function (options) {
    	_.bindAll(this,"render","toggleMessageWindow","closeLogin");
    },
    render: function () {
    	var self = this; 

        this.$el.prepend((this.messagePane = new MessageListView()).render().el);
        this.loginPane = new LoginView();
        this.$el.prepend((this.helpPane = new HelpView()).render().el);
        
        $("button#help-link").click(function () {
                self.helpPane.open();});

        $("button#msg-toggle").on("click",this.toggleMessageWindow);

                // this is just for testing

        $(".navbar-right>li:nth-child(1)").on("click", function () {
            console.log("testing the login");
            self.loginPane.render().open();
        })


         this.setUpNavMenu();  

    },
    toggleMessageWindow: function() {
        this.messagePane.toggle();
    },
    closeLogin: function () {
        this.loginPane.close();
    },

    // setUpNavMenu will dynamically changed the navigation menu to make it look better in the bootstrap view.
    // In the future, we need to have the template for the menu better suited for a navigation menu.  

    setUpNavMenu: function ()
    {
        var allCourses = $("#webwork_navigation ul:eq(0)").addClass("dropdown-menu");
        var InstructorTools = $("#webwork_navigation ul:eq(0) ul:eq(0) ul:eq(0)");
        var StudentTools = $("#webwork_navigation ul:eq(0) ul:eq(0)");



        InstructorTools.children("ul").remove();  // remove any links under the instructor tools
        StudentTools.children("ul").remove(); // remove 
        allCourses.children("ul").remove();

        allCourses.append("<li class='divider'>").append(StudentTools.children("li"))
            .append("<li class='divider'>").append(InstructorTools.children("li"));

        var activeLink = $("#webwork_navigation strong").children();
        var strongElem = $("#webwork_navigation strong").parent();
        strongElem.children().remove();
        strongElem.addClass("active").append(activeLink);

        $("#webwork_navigation").removeAttr("style")

    },
    requestLogin: function (opts){
        this.loginPane.loginOptions = opts;
        this.loginPane.render().open();

    },
    setLoginTemplate: function(opts){
        this.loginPane.set(opts);
    }


});

var LoginView = ModalView.extend({
    initialize: function (options) {
        _.bindAll(this,"login");
        var tempOptions = _.extend(options || {} , {template: $("#login-template").html(), 
                        templateOptions: {message: config.msgTemplate({type: "relogin"})},
                        buttons: {text: "Login", click: this.login}});
        this.constructor.__super__.initialize.apply(this,[tempOptions]);
    },
    render: function () {
        this.constructor.__super__.render.apply(this); 
        return this;
    },
    login: function () {
        console.log("logging in");
        var loginData = {user: this.$(".login-name").val(), password: this.$(".login-password").val()};
        $.ajax({url: config.urlPrefix + "courses/" + config.courseSettings.course_id + "/login",
                data: loginData,
                type: "POST",
                success: this.loginOptions.success});
    }

});

var HelpView = Backbone.View.extend({
    className: "ww-help hidden alert alert-info",
    render: function (){
        this.$el.html($("#help-template").html());
        this.$(".help-text").html($("#help-text").html());
        return this;
    },
    open: function(){
        this.$el.removeClass("hidden");
    },
    close: function() {
        this.$el.addClass("hidden");
    },
    events: {"click .close-help-button": "close"}
});


return WebPage;
});