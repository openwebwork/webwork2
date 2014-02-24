define(['module','backbone', 'underscore','models/UserSetListOfSets', 'views/WebPage','UserSetView', 'models/UserSet',
    'models/UserProblemList', 'StudentCalendarView','models/AssignmentDateList','models/AssignmentDate','models/Settings', 'config'], 
function(module,Backbone, _, UserSetListOfSets, WebPage, UserSetView, UserSet, UserProblemList, StudentCalendarView, 
            AssignmentDateList,AssignmentDate,Settings,config){

var FrontPage = WebPage.extend({
    tagName: "div",
    initialize: function(){
        this.constructor.__super__.initialize.apply(this, {el: this.el});
        //WebPage.prototype.initialize.apply(this, );
        _.bindAll(this, 'render','checkLogin','showProblemSets','processUserProblems','buildProblemSetPulldown',
                        'changeView','changeSet');  // include all functions that need the this object
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

        Backbone.Stickit.addHandler({
            selector: ".problems",
            onGet: function(probs){ 
                if(probs) {
                    return probs.length;
                }}});
        Backbone.Stickit.addHandler({
            selector: ".score",
            onGet: function(probs){
            if(probs){
                var possiblePoints = 0
                    , currentPoints = 0;
                probs.each(function(p){
                    possiblePoints+=parseFloat(p.get("value")||"0");
                    currentPoints+=parseFloat(p.get("status")||"0");
                })
                return currentPoints.toFixed(3)+"/"+possiblePoints;
            }}});
    },
    render: function(){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 

        this.$el.html($("#home-page-template").html());
        this.setInfoView = new SetInfoView({el: $("#problem-set-info-container")});

        $("ul.nav a").on("click",this.changeView);
        
    },
    changeView: function(evt){
        $("ul.navbar-nav > li").removeClass("active");
        $(evt.target).parent().addClass("active");
        switch($(evt.target).data("link")){
            case "progress":
                this.showProblemSets();
            break;
            case "calendar":
                this.buildAssignmentDates();
                new StudentCalendarView({el: this.$(".problem-set-container"),assignmentDates: this.assignmentDateList,
                            calendarType: "month", userSets: this.userSetList}).render();
            break;

        }
    },
        // This travels through all of the assignments and determines the days that assignment dates fall
    buildAssignmentDates: function () {
        var self = this;
        this.assignmentDateList = new AssignmentDateList();
        this.userSetList.each(function(_set){
            self.assignmentDateList.add(new AssignmentDate({type: "open", problemSet: _set,
                    date: moment.unix(_set.get("open_date")).format("YYYY-MM-DD")}));
            self.assignmentDateList.add(new AssignmentDate({type: "due", problemSet: _set,
                    date: moment.unix(_set.get("due_date")).format("YYYY-MM-DD")}));
            self.assignmentDateList.add(new AssignmentDate({type: "answer", problemSet: _set,
                    date: moment.unix(_set.get("answer_date")).format("YYYY-MM-DD")}));


        });
    },

    postLoginRender: function(){
        config.settings = new Settings();
        config.settings.fetch({success: function(){
        }});
        this.userSetList = new UserSetListOfSets([],{user: config.courseSettings.user});
        this.userSetList.fetch({success: this.buildProblemSetPulldown});
        $(".login-container").html(_.template($("#logged-in-template").html(),{user: config.courseSettings.user}));
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
        this.userSetList.on("showSet",this.changeSet);

    },
    showProblemSets: function() {
        var self = this;
        this.userSetListView = new UserSetListView({el: this.$(".problem-set-container"), 
            userSetList: this.userSetList}).render();
        this.userSetList.each(function(_set,i){
            _set.problems = new UserProblemList([],{set_id: _set.get("set_id"),user_id: _set.get("user_id")});
            _set.problems.fetch({success: self.processUserProblems});
        });

        $("a.setname").off("click").on("click",this.changeSet);



    },
    processUserProblems: function (problems) {
        var _set = this.userSetList.get(problems.set_id);
        _set.set("problems",_set.problems);
        //_set.trigger("change:problems",_set);
    },
    changeSet: function (evt){
        var _set;
        if (evt instanceof UserSet){
            _set = evt;
        } else {
            _set = this.userSetList.findWhere({set_id: $(evt.target).data("setname")});
        }
        this.userSetView = new UserSetView({el: this.$(".problem-set-container")});
        this.userSetView.set({userSet: _set}).render();
        this.setInfoView.set({userSet: _set}).render();
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
        ".problems": "problems",
        ".score": "problems"
    }
});

var SetInfoView = Backbone.View.extend({

    render: function (){
        this.$el.html($("#set-info-template").html());
        if(this.model.get("enable_reduced_scoring")==="1"){
            this.$(".reduced-credit-row").html($("#reduced-credit-template").html());
        }
        this.stickit();
        return this;
    },
    set: function(options){
        this.model = options.userSet;
        return this;
    },
    bindings: {
        ".setname": "set_id",
        ".problems": "problems",
        ".score": "problems",
        ".open-date": "open_date",
        ".due-date": "due_date",
        ".answer-date": "answer_date",
        ".reduced-credit-date": {observe: "due_date",
            onGet: function(val){
                var mins = config.settings.findWhere({var: "pg{ansEvalDefaults}{reducedScoringPeriod}"}).get("value");
                return moment.unix(val).subtract("minutes",mins).format("MM/DD/YYYY [at] hh:mmA")
            }
        }
    }
    //         updateMethod: "html",
    //         update: function($el, val, model, options) { 
    //             if(model.get("enable_reduced_scoring")==="1"){
    //                 var mins = config.settings.findWhere({var: "pg{ansEvalDefaults}{reducedScoringPeriod}"}).get("value");
    //                 var reduced_credit_date = moment.unix(model.get("due_date")).subtract("minutes",mins);
    //                $el.html(this.reducedCreditTemplate({reduced_credit_date: reduced_credit_date.format("MM/DD/YYYY [at] hh:mmA")}));                   
    //             }
 
    //         }
    //     }
    // }
});


var App = new FrontPage({el: $("#main")});
});