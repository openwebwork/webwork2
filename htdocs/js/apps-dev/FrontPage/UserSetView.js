define(['module','Backbone', 'underscore','config','models/UserProblemList','views/ProblemView'], 
function(module,Backbone, _, config,UserProblemList,ProblemView){

var UserSetView = Backbone.View.extend({
	initialize: function(options){
		_.bindAll(this,"changeProblem","postCheckAnswer");
	},
	render: function(){
		if(this.userSet){
			this.$el.html(_.template($("#problem-list-template").html(),this.userSet.attributes));
			this.changeProblem(1);
		} else {
			this.$el.html($("#user-set-template").html());			
		}

		
	},
	set: function(options){
		this.userSet = options.userSet;
		return this;
	},
	events: {"click .problem-button": "changeProblem",
		"click .preview-answer-button": "previewAnswer",
		"click .check-answer-button": "checkAnswer",
		"click .submit-answer-button": "submitAnswer"},

	changeProblem: function(evt){
		var probNumber = parseInt(/^\d+$/.test(evt)?evt:$(evt.target).text());
        this.currentProblem = this.userSet.get("problems").at(probNumber-1);
        this.problemViewAttrs = {reorderable: false, showPoints: true, showAddTool: false, showEditTool: false,
                    showRefreshTool: false, showViewTool: false, showHideTool: false, deletable: false, draggable: false,
                	displayMode: "MathJax" 
                };

        var problemView = new ProblemView({model: this.currentProblem,viewAttrs: this.problemViewAttrs});
        this.$(".problem-container ul").html(problemView.render().el);
        this.$(".pagination li").removeClass("active");
        this.$(".pagination li:nth-child("+probNumber+")").addClass("active");
    },
    checkAnswer: function(){
    	this.$(".check-answer-button").button("loading");
    	this.currentProblem.checkAnswers(this.parseAnswers(),this.postCheckAnswer);
    },
    submitAnswer: function(){
    	this.$(".check-answer-button").button("loading");
    	this.currentProblem.submitAnswers(this.parseAnswers(),this.postCheckAnswer);
    },

    parseAnswers: function (){
    	var ansIDs = _.union($.makeArray($("[name^=AnSwEr]").map(function(i,v) { return $(v).attr("id");})));

    	var answers = {};
    	_(ansIDs).each(function(id){
    		if($("#"+id).is("select")){
    			answers[id] = $("#"+id).val();
    		} else if ($("#"+id).is("input")){
	    		switch($("#"+id).attr("type").toLowerCase()){
	    			case "radio": 
	    				answers[id] = $("input[name='"+id+"']:checked").val();
	    				break;
	    			case "text":
	    				answers[id] = $("#"+id).val(); 
	    				break;
	    		}
	    	}
    	})
    	return answers; 

    },
    postCheckAnswer: function(response){
    	this.$(".check-answer-button").button("reset");
    	console.log(response);
    	_(_.keys(response.answers)).each(function(ans){
    		if($("#"+ans).parent().hasClass("alert")){
    			$("#"+ans).unwrap();
    		}
    		if (response.answers[ans].score==0){
	    		$("#"+ans).wrap("<span class='alert alert-danger' style='padding:7px 5px 7px 7px'></span>");
	    	} else {
	    		$("#"+ans).wrap("<span class='alert alert-success' style='padding:7px 5px 7px 7px'></span>");
	    	}
    	})
    	$("#AnSwEr0001")

    }
});

return UserSetView; 
});