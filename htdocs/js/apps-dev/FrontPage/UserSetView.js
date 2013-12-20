define(['module','Backbone', 'underscore','config','models/UserProblemList','views/ProblemView','models/PastAnswerList',
            'models/PastAnswer'], 
function(module,Backbone, _, config,UserProblemList,ProblemView,PastAnswerList,PastAnswer){

var UserSetView = Backbone.View.extend({
	initialize: function(options){
		_.bindAll(this,"changeProblem","postCheckAnswer","postSubmitAnswer","loadPastAnswers","showLastAnswer",
                "denoteRightWrong");
		this.problemInfoView = new ProblemInfoView({el: $("#problem-info-container")});
	},
	render: function(){
        var self = this;
		if(this.userSet){
			this.userSet.get("problems").on("rendered",this.showLastAnswer);
			this.$el.html(_.template($("#problem-list-template").html(),this.userSet.attributes));
			this.changeProblem(1);
            this.userSet.get("problems").each(function(prob){
                self.labelProblemButton(prob.get("problem_id"));
            })
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
        if(this.currentProblem){
            this.labelProblemButton(this.currentProblem.get("problem_id"));
        }
		var probNumber = parseInt(/^\d+$/.test(evt)?evt:$(evt.target).text());
        $("li.problem-li[data-number='"+probNumber+"'] a").css("background","");
        this.currentProblem = this.userSet.get("problems").at(probNumber-1);
        this.pastAnswerList = new PastAnswerList([],{userSet: this.userSet, problem: this.currentProblem});
        this.pastAnswerList.fetch({success: this.loadPastAnswers});

        this.problemViewAttrs = {reorderable: false, showPoints: true, showAddTool: false, showEditTool: false,
                    showRefreshTool: false, showViewTool: false, showHideTool: false, deletable: false, draggable: false,
                	displayMode: "MathJax" 
                };
        if(this.currentProblem){
            this.problemInfoView.set({problem: this.currentProblem}).render();
            this.problemView = new ProblemView({model: this.currentProblem,viewAttrs: this.problemViewAttrs});
            this.$(".problem-container ul").html(this.problemView.el);
            this.problemView.render();
        }
        this.$(".pagination li").removeClass("active");
        this.$(".pagination li:nth-child("+probNumber+")").addClass("active");

        this.lastAnswerShown = false;

    },
    checkAnswer: function(){
    	this.$(".check-answer-button").button("loading");
    	this.currentProblem.checkAnswers(this.parseAnswers(),this.postCheckAnswer);
    },
    submitAnswer: function(){
    	this.$(".submit-answer-button").button("loading");
    	this.currentProblem.submitAnswers(this.parseAnswers(),this.postSubmitAnswer);
        this.pastAnswerList.fetch();

    },
    parseAnswers: function (){
    	var ansIDs = this.problemView.model.renderData.flags.ANSWER_ENTRY_ORDER;

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
    loadPastAnswers: function(data){
    	this.pastAnswerList = data;
    	this.pastAnswerListView = new PastAnswerListView({el: $("#past-answer-list-container"), 
    			collection: this.pastAnswerList}).render();
    	if(this.problemView.model.renderData){
    		this.showLastAnswer();
    	}
    },
    showLastAnswer: function(){
    	this.lastAnswerShown = true;
		var scores = this.pastAnswerList.last() ? this.pastAnswerList.last().get("scores"): ""
    	    , ansIDs = this.problemView.model.renderData.flags.ANSWER_ENTRY_ORDER
            , answerString = this.pastAnswerList.last() ? this.pastAnswerList.last().get("answer_string").split(/\t/): null
            , answer;
        if (answerString){
             answer = _(ansIDs).map(function(_id,i) { return {id: _id, score: scores[i], answer: answerString[i]};});
            this.denoteRightWrong(answer);
        }
    },
    postCheckAnswer: function(response){
    	this.$(".check-answer-button").button("reset");
        this.formatAnswer(response.answers);
    },
    formatAnswer: function(_answers){
        var self = this;
        var answers = _(_.keys(_answers)).map(function(key) { return {id: key, score: _answers[key].score, 
                    answer: _answers[key].student_ans};});
        this.denoteRightWrong(answers);
        this.currentProblem.fetch({success: function(resp){
            self.userSet.trigger("change:problems",self.userSet);
        }});
    },
    postSubmitAnswer: function(response){
    	this.$(".submit-answer-button").button("reset");
        this.formatAnswer(response.answers);
    },
    /* This method shows whether an answer is right or wrong by putting a red or green box around the answer
    *  It expected an array of objects with keys id, score (0 or 1) and answer ()
    *
    *  In addition, if there are answers previously, then they are filled in
    */
    denoteRightWrong: function(answers){
    	_(answers).each(function(ans){
            var elem; 
            if($("#"+ans.id).is("input") && $("#"+ans.id).attr("type").toLowerCase()==="radio"){
                elem = $("[name='"+ans.id+"'][value='"+ans.answer+"']");
                elem.prop("checked",true);
            } else {
                elem = $("#"+ans.id).val(ans.answer);
            }
        
    		if(elem.parent().hasClass("alert")){
    			elem.unwrap();
    		}
         	if (parseInt(ans.score)===0){
	    		elem.wrap("<span class='alert alert-danger' style='padding:7px 5px 7px 7px'></span>");
	    	} else if (parseInt(ans.score)===1){
	    		elem.wrap("<span class='alert alert-success' style='padding:7px 5px 7px 7px'></span>");
	    	}
    	});
    },
    labelProblemButton: function(num){
        var status = 100-parseInt(100*parseFloat(this.userSet.get("problems").findWhere({problem_id: num}).get("status")));
        $("li.problem-li[data-number='"+num+"'] a").css("background","-webkit-linear-gradient(top, white " +
            status + "%, rgba(0,255,0,0.25) "+status+"%)");
    }
});

var ProblemInfoView = Backbone.View.extend({
	render: function (){
		this.$el.html($("#problem-info-template").html());
        if(this.model){
    		this.stickit();
        }
		return this;
	},
	set: function(options){
		this.model = options.problem;
		return this;
	},
	bindings: {
		".prob-id": "problem_id",
		".prob-score": "status",
	}
});

var PastAnswerListView = Backbone.View.extend({
    initialize: function(){
        _.bindAll(this,"render");
        this.collection.on("add",this.render);
    },
	render: function (){
		this.$el.html($("#past-answer-list-template").html());
		var table = this.$("table tbody");
		this.collection.each(function(_model){
			table.append(new PastAnswerView({model: _model}).render().el);
		})
		return this;
	}
});

var PastAnswerView = Backbone.View.extend({
	tagName: "tr",
	render: function (){
		//this.$el.html($("#past-answer-template").html());
		this.stickit();
		return this;
	},
	bindings: { ":el": {
		observe: ["answer_string","timestamp","scores"], 
		updateMethod: 'html',
		onGet: function(value){
			var answers = value[0].split(/\t/);
			answers.pop();
			var str = "";
			_(answers).each(function(ans,i){
				str += "<td style='color:"+(value[2].substring(i,i+1)==="1"?"green":"red")+"'>"+ans+"</td>";
			});
			return str + "<td>"+moment.unix(value[1]).format("MM/DD/YYYY [at] hh:mmA") +"</td>";
	}}}
});

return UserSetView; 
});