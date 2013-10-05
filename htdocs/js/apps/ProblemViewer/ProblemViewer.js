/*  ProblemViewer.js:
   This is the base javascript code for a student or instructor view of the problem.  
  
*/
define(['module','Backbone', 'underscore','views/WebPage','models/Problem','views/ProblemView','models/UserProblemList',
        'models/UserSet','models/PastAnswerList','config', 'bootstrap','imagesloaded'],
function(module, Backbone, _, WebPage,Problem,ProblemView,UserProblemList,UserSet,PastAnswerList,config){
var ProblemViewer = WebPage.extend({

    initialize: function () {
        _.bindAll(this,"render","checkAnswer","changeProblem","showPastAnswers");

        this.userSet = (module.config().userSet) ? new UserSet(module.config().userSet): new UserSet();
        config.courseSettings.courseID = module.config().course_id;
        config.courseSettings.user = module.config().user;

        if (module.config().problems){
            this.collection = new UserProblemList(module.config().problems);
            console.log(this.collection);
            if (this.userSet.get("set_id")){
                this.collection.setName = this.userSet.get("set_id");
            }
        }
        this.problemViewAttrs = {reorderable: false, showPoints: true, showAddTool: false, showEditTool: false,
                    showRefreshTool: false, showViewTool: false, showHideTool: false, deletable: false, draggable: false};

        this.currentProblem = this.collection.at(0);
        this.render();
    },

    render: function () {
        var problemView = new ProblemView({model: this.currentProblem,viewAttrs: this.problemViewAttrs});
        this.$el.html(_.template($("#problem-list-template").html(),{problems: this.collection}));
        this.$("ul").append(problemView.render().el);
    }, 
    events: {"blur .codeshard": "checkAnswer",
            "click .problem-button": "changeProblem",
            "click .show-past-answers-btn": "showPastAnswers"},
    showPastAnswers: function () {
        if (this.pastAnswerList){
            (new PastAnswerListView({el: $("#show-past-answers"),collection: this.pastAnswerList})).render();
        } else {
            this.pastAnswerList = new PastAnswerList({user_set: this.userSet, problem: this.currentProblem});
            this.pastAnswerList.fetch({success: this.showPastAnswers});
        }
    },
    checkAnswer: function(evt) {
        if ($(evt.target).val()){
            var answers = {};
            answers[$(evt.target).attr("id")] = $(evt.target).val();
            this.currentProblem.checkAnswers(answers,this.showResult);
        }
    },
    changeProblem: function (evt){
        this.currentProblem = this.collection.at(parseInt($(evt.target).text())-1);
        this.pastAnswerList = null;
        this.render();
    },
    showResult: function(data){
        var answerNames = _.keys(data.answers);
        console.log("is the answer right?");
        console.log(data);
        _(answerNames).each(function(name){
            if(data.answers[name].score==0){
                $("#"+name).css('background-color','rgba(255,0,0,0.25)');
            } else if(data.answers[name].score==1){ 
                $("#"+name).css('background-color','rgba(0,255,0,0.25)');
            }
        })
    }

});

var PastAnswerListView = Backbone.View.extend({
    initialize: function () {
        _.bindAll(this,"render");
    },
    render: function (){
        this.$el.html($("#past-answer-list-template").html());
        var table = this.$(".past-answer-table tbody");
        this.collection.each(function(pastAnswer){
            table.append((new PastAnswerView({model: pastAnswer})).render().el);
        })
        return this;
    }

});

var PastAnswerView = Backbone.View.extend({
        tagName: "tr",
        initialize: function () {
        _.bindAll(this,"render");
    },
    bindings: {".answer_date": "timestamp",
               ".answer": {
                    observe: ['answer_string', 'scores'],
                    updateMethod: 'html',
                    onGet: function(vals,options){
                        var answers = vals[0].split(/\t/);
                        return _(answers).map(function(ans,i){
                            return vals[1].charAt(i) == 1 ? 
                                    "<span class='correct'>" +ans + "</span>" :
                                    "<span class='wrong'>" + ans + "</span>";
                        }).join("");
                    }
    }},
    render: function (){
        this.$el.html($("#past-answer-template").html());
        this.stickit();
        return this;
    }

});

var App = new ProblemViewer({el: $("div#problem-viewer")});
});