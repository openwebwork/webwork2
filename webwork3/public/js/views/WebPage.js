define(['backbone','views/MessageListView','views/ModalView','config','views/NavigationBar', 'jquery-truncate'], 
function(Backbone,MessageListView,ModalView,config,NavigationBar){
	var WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    messageTemplate: _.template($("#general-messages").html()),
    initialize: function (options) {
    	_.bindAll(this,"render","closeLogin");
    },
    render: function () {
    	var self = this; 

        this.$el.prepend((this.messagePane = new MessageListView()).render().el);
        this.loginPane = new LoginView({messageTemplate: this.messageTemplate});
        this.$el.prepend((this.helpPane = new HelpView()).render().el);
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
    }


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