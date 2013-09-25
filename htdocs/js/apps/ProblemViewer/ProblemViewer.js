/*  ProblemViewer.js:
   This is the base javascript code for a student or instructor view of the problem.  
  
*/
define(['module','Backbone', 'underscore','views/WebPage','models/Problem','views/ProblemView','models/UserProblemList',
        'bootstrap'],
function(module, Backbone, _, WebPage,Problem,ProblemView,UserProblemList){
var ProblemViewer = WebPage.extend({

    initialize: function () {
        _.bindAll(this,"render","checkAnswer","changeProblem");

        if (module.config().problems){
            this.collection = new UserProblemList(module.config().problems);
            if (this.collection.at(0).get("set_id")){
                this.collection.setName = this.collection.at(0).get("set_id");
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
            "click .problem-button": "changeProblem"},
    checkAnswer: function(evt) {
        if ($(evt.target).val()){
            var answers = {};
            answers[$(evt.target).attr("id")] = $(evt.target).val();
            this.currentProblem.checkAnswers(answers,this.showResult);
        }
    },
    changeProblem: function (evt){
        this.currentProblem = this.collection.at(parseInt($(evt.target).text())-1);
        console.log(this.currentProblem);
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

var App = new ProblemViewer({el: $("div#problem-viewer")});
});