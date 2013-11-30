define(['module','Backbone', 'underscore','config','models/UserProblemList','views/ProblemView'], 
function(module,Backbone, _, config,UserProblemList,ProblemView){

var UserSetView = Backbone.View.extend({
	initialize: function(options){
		_.bindAll(this,"showProblems");
	},
	render: function(){
		this.$el.html($("#user-set-template").html());
		
	},
	set: function(options){
		this.userSet = options.userSet;
		this.userProblems = new UserProblemList([],{user_id: this.userSet.get("user_id"),set_id: this.userSet.get("set_id")});
		this.userProblems.fetch({success: this.showProblems});
		return this;
	},
	showProblems: function (){
		// set up a paginator
		this.$el.html(_.template($("#problem-list-template").html(),
				{set_id: this.userSet.get("set_id"),problems: this.userProblems}));

	},
	events: {"click .problem-button": "changeProblem"},
	changeProblem: function(evt){
        this.currentProblem = this.userProblems.at(parseInt($(evt.target).text())-1);
        //this.pastAnswerList = null;
        this.problemViewAttrs = {reorderable: false, showPoints: true, showAddTool: false, showEditTool: false,
                    showRefreshTool: false, showViewTool: false, showHideTool: false, deletable: false, draggable: false,
                	displayMode: "MathJax" 
                };

        var problemView = new ProblemView({model: this.currentProblem,viewAttrs: this.problemViewAttrs});
        this.$(".problem-container ul").html(problemView.render().el);

    },
});

return UserSetView; 
});