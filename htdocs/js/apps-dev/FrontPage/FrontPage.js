define(['module','Backbone', 'underscore','models/UserSetListOfSets', 'views/WebPage','UserSetView',
    'views/CalendarView','config'], 
function(module,Backbone, _, UserSetListOfSets, WebPage, UserSetView, CalendarView, config){

var FrontPage = WebPage.extend({
    tagName: "div",
    initialize: function(){
        this.constructor.__super__.initialize.apply(this, {el: this.el});
        //WebPage.prototype.initialize.apply(this, );
        _.bindAll(this, 'render','checkLogin','showSet');  // include all functions that need the this object
        var self = this;
        this.render();
        if(module.config().session){
            _.extend(config.courseSettings,module.config().session);
        }
        if(typeof(config.courseSettings.course_id)==="undefined"){
            config.courseSettings.course_id = module.config().course_id;
        }

        if(! config.courseSettings.logged_in){
            this.constructor.__super__.requestLogin.call(this, {success: this.checkLogin});
        } else {
            this.postLoginRender();
        }

    },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 

        this.$el.html($("#home-page-template").html());
    },
    postLoginRender: function(){
        this.userSetListView = new UserSetListView({el: this.$(".problem-set-list-container"),user:config.courseSettings.user});
        this.userSetListView.userSetList.on("show-set",this.showSet);
        this.userSetView = new UserSetView({el: this.$(".problem-set-container")});
    },
    checkLogin: function(data){
        if(data.logged_in==1){
            this.loginPane.close();
            _.extend(config.courseSettings,data);
            this.postLoginRender();
        } else {
            this.loginPane.$(".message").html(config.msgTemplate({type: "bad_password"}));
        }
    },
    showSet: function(_set){
        this.userSetView.set({userSet: _set}).render();
    }
});

var UserSetListView = Backbone.View.extend({
    initialize: function (options){
        _.bindAll(this,"render");
        this.userSetList = new UserSetListOfSets([],{user: options.user});
        this.render();
        this.userSetList.fetch({success: this.render});

    },
    render: function(){
        var self = this;
        if(this.userSetList.length===0){ 
            this.$el.html($("#loading-problems-template").html())
        } else {
            this.$el.html($("#problem-set-list-template").html());
            var ul = this.$(".problem-set-list");
            this.userSetList.each(function(_set){
                ul.append((new UserSetNameView({model: _set,userSetList: self.userSetList})).render().el);
            })
        }
    }
});

var UserSetNameView = Backbone.View.extend({
    tagName: "li",
    initialize: function (options){
        this.userSetList = options.userSetList;
    },
    render: function(){
        this.stickit();
        return this;
    },
    events: { "click .setname": "showSet"},
    bindings: {":el": {observe: "set_id", update: function($el, val){
        $el.html("<a class='setname' data-setname='"+val+"' href='#'>"+val+"</a>");
    }}},
    showSet: function(evt){
        var _set = this.userSetList.findWhere({set_id: $(evt.target).data("setname")});
        _set.trigger("show-set",_set);
    }
})


var App = new FrontPage({el: $("#main")});
});