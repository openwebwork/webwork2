define(['module','Backbone', 'underscore','models/UserSetListOfSets', 'views/WebPage','UserSetView',
    'models/UserProblemList', 'views/CalendarView','config'], 
function(module,Backbone, _, UserSetListOfSets, WebPage, UserSetView, UserProblemList, CalendarView, config){

var FrontPage = WebPage.extend({
    tagName: "div",
    initialize: function(){
        this.constructor.__super__.initialize.apply(this, {el: this.el});
        //WebPage.prototype.initialize.apply(this, );
        _.bindAll(this, 'render','checkLogin','showProblemSets','processUserProblems','buildProblemSetPulldown',
                        'changeView');  // include all functions that need the this object
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

        $("ul.nav a").on("click",this.changeView);
        
    },
    changeView: function(evt){
        switch($(evt.target).data("link")){
            case "progress":
                this.showProblemSets();
            break;
            case "calendar":
            break;

        }
    },
    postLoginRender: function(){
        this.userSetList = new UserSetListOfSets([],{user: config.courseSettings.user});
        this.userSetList.fetch({success: this.buildProblemSetPulldown});
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
    buildProblemSetPulldown: function (){
        var self = this;
        var ul = $(".problem-set-dropdown");
        var template =_.template($("#problem-set-template").html()); 
        this.userSetList.each(function(_set){
            ul.append(template(_set.attributes));
        });
        this.showProblemSets();

    },
    showProblemSets: function() {
        var self = this;
        this.userSetListView = new UserSetListView({el: this.$(".problem-set-container"), 
            userSetList: this.userSetList}).render();
        this.userSetList.each(function(_set,i){
            _set.problems = new UserProblemList([],{set_id: _set.get("set_id"),user_id: _set.get("user_id")});
            _set.problems.fetch({success: self.processUserProblems});
        });

        $("a.setname").off("click").on("click",function(evt){
            //console.log($(evt.target));
            self.userSetView = new UserSetView({el: self.$(".problem-set-container")});
            var _set = self.userSetList.findWhere({set_id: $(evt.target).data("setname")});
            self.userSetView.set({userSet: _set}).render();
        });

    },
    processUserProblems: function (problems) {
        var _set = this.userSetList.get(problems.set_id);
        _set.set("problems",_set.problems);
        //_set.trigger("change:problems",_set);
    }

});

var UserSetListView = Backbone.View.extend({
    initialize: function (options){
        this.userSetList = options.userSetList;

        this.openSetList = this.userSetList.filter(function(_set){
            return moment().isAfter(moment.unix(_set.get("open_date"))) && moment().isBefore(moment.unix(_set.get("due_date")));
        });
        this.closedSetList = _(this.userSetList.filter(function(_set){
            return moment().isAfter(moment.unix(_set.get("due_date")));
        })).sortBy(function(_set){
            return _set.get("due_date");
        })

    },
    render: function(){
        this.$el.html($("#user-set-list-table-template").html());
        var openTable = this.$(".open-assigns tbody");
        _(this.openSetList).each(function(_set){
            openTable.append((new UserSetRowView({model: _set})).render().el);
        });
        var closedTable = this.$(".closed-assigns tbody");
        _(this.closedSetList).each(function(_set){
            closedTable.append((new UserSetRowView({model: _set})).render().el);
        });
    }
});

var UserSetRowView = Backbone.View.extend({
    tagName: "tr",
    initialize: function (options){
        this.userSetList = options.userSetList;
    },
    render: function(){
        this.$el.html($("#user-set-table-row-template").html());
        this.stickit();
        return this;
    },
//    events: { "click .setname": "showSet"},
    bindings: {".setname": {observe: "set_id" , update: function($el,val,model,options){
        $el.html(_.template($("#problem-set-name-template").html(),{set_id: val}));
    }},
        ".due-date": "due_date",
        ".problems": {observe: "problems", onGet: function(probs){ 
            if(probs) {
                return probs.length;
            }}},
        ".score": {observe: "problems", onGet: function(probs){
            if(probs){
                var possiblePoints = 0
                    , currentPoints = 0;
                probs.each(function(p){
                    possiblePoints+=parseInt(p.get("value"));
                    currentPoints+=parseInt(p.get("status"));
                })
                return currentPoints+"/"+possiblePoints;
            }}}

        }
})


var App = new FrontPage({el: $("#main")});
});