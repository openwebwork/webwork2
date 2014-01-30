define(['module','Backbone', 'underscore','models/UserSetList', 'views/WebPage',
    'views/CalendarView','config'], 
function(module,Backbone, _, UserSetList, WebPage, CalendarView, config){

var FrontPage = WebPage.extend({
    tagName: "div",
    initialize: function(){
        this.constructor.__super__.initialize.apply(this, {el: this.el});
        //WebPage.prototype.initialize.apply(this, );
        _.bindAll(this, 'render','postHWLoaded','checkLogin');  // include all functions that need the this object
        var self = this;
        this.render();
        if(module.config().session){
            _.extend(config.courseSettings,module.config().session);
        }

        if(! config.courseSettings.logged_in){
            this.constructor.__super__.requestLogin.call(this, {success: this.checkLogin});
        }

    },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 

        /*this.probSetListView = new ProblemSetListView({el: $("#left-column"), viewType: "student",
                                collection: this.problemSets, parent: this});

        this.helpPane.open();*/
   },
    postHWLoaded: function () {
        var self = this;

        self.calendarView = new CalendarView({el: $("#cal"), collection: self.problemSets,  parent: this, view: "student"});

        $(".problem-set").on("click",function(evt) {
            console.log($(evt.target).data("setname"));  // Not the best way to do this, but should work. 
            location.href="./" + $(evt.target).data("setname") + "?effectiveUser=" + $("#hidden_effectiveUser").val() 
                    + "&key=" + $("#hidden_key").val() + "?user=" + $("#hidden_user").val();
        })         
        // Set the popover on the set name
    //   $("span.pop").popover({title: "Homework Set Details", placement: "top", offset: 10});
        
        //self.setListView = new SetListView({collection: self.collection, el:$("div#list")});
    },
    checkLogin: function(data){
        if(data.logged_in==1){
            this.loginPane.close();
            _.extend(config.courseSettings,data);
            this.showProblemSetList();
        } else {
            this.loginPane.$(".message").html(config.msgTemplate({type: "bad_password"}));
        }
    },
    showProblemSetList: function(){
        new UserSetListView({el: $("#main"),user:config.courseSettings.user});
    }
});

var UserSetListView = Backbone.View.extend({
    initialize: function (options){
        this.userSetList = new UserSetList([],{user: options.user});
        this.render();
        this.userSetList.fetch({success: this.render});

    },
    render: function(){
        if(this.userSetList.length===0){ 
            this.$el.html($("#loading-problems-template").html())
        } else {
            console.log(this.userSetList);
        }
    },
});


var App = new FrontPage({el: $("#main")});
});