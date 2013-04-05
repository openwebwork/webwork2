/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['Backbone', 'underscore','./ProblemListView','../models/ProblemList','./LibraryTreeView'], 
function(Backbone, _,ProblemListView, ProblemList,LibraryTreeView){
    var LibraryView = Backbone.View.extend({
        className: "lib-browser",
    	tagName: "td",
    	initialize: function (){
    		var self = this; 
            _.bindAll(this,'render','changeView','showProblems','addProblem');
            this.allProblemSets = this.options.problemSets;
            this.errorPane = this.options.errorPane;
            this.libBrowserType = this.options.libBrowserType;
            this.dispatcher = {};
            _.extend(this.dispatcher, Backbone.Events);

    		this.dispatcher.on("load-problems", function(path) { self.loadProblems(path);});

            // The following needs to be changed it's being called when the problem set list is shown.  

            this.dispatcher.on("num-problems-shown", function(num){
                    if (self.libraryTreeView){
                        self.libraryTreeView.$("span.library-tree-right").html(num + " of " + self.problemList.size() + " shown");
                    }
            });
            this.libraryTreeView = new LibraryTreeView({dispatcher: this.dispatcher, orientation: "dropdown", type: this.libBrowserType});

            this.problemViewAttrs = {reorderable: false, showPoints: false, showAddTool: true, showEditTool: true,
                    showRefreshTool: true, showViewTool: true, showHideTool: true, deletable: false, draggable: true};

            
    	},
    	events: {"change #library-selector": "changeView",
                    "change .target-set": "resetDisplayModes"},
    	render: function (){
            var self = this;

    		this.$el.html(_.template($("#library-view-template").html(), {sets: this.allProblemSets.pluck("set_id")}));
            this.libraryTreeView.render();
            this.$(".library-viewer").append(this.libraryTreeView.el);

    		this.$(".lib-problem-viewer").height(0.8*screen.height);

            var targetSetSelect = self.$(".target-set")
    		
/*            this.allProblemSets.each(function(set){
                    targetSetSelect.append(_.template($("#target-set-template").html(),set.attributes)) 
                }); */

    	},
        showProblems: function (){
            console.log("in showProblems");
            var plv = new ProblemListView({el: this.$(".lib-problem-viewer"), type: this.libBrowserType,  
                                                viewAttrs: this.problemViewAttrs, headerTemplate: "#library-problems-header"});
            plv.setProblems(this.problemList);
            this.problemList.on("add-to-target",this.addProblem);
        },
        addProblem: function(model){
            var targetSet = this.$(".target-set option:selected").val();
            var problemSet = this.allProblemSets.find(function(set) {return set.get("set_id")===targetSet});
            console.log(problemSet);
            if(!problemSet){
                this.errorPane.addMessage({text: "You need to select a target set"});
                this.$(".target-set").css('background-color','pink');
                return;
            }
            if (!problemSet.problems){
                problemSet.problems = new ProblemList();
                }
            problemSet.problems.add(model);

        },
    	changeView: function (evt) {
    		var self = this;
            $(".lib-problem-viewer").html("");

    	},
    	loadProblems: function (_path)
    	{
    		console.log(_path);
			this.problemList = new ProblemList({path:  _path, type: "Library Problems"});
            this.problemList.on("fetchSuccess",this.showProblems,this);
    	}, 
        resetDisplayModes: function(){
            this.$('.target-set').css('background-color','white');
        }

    });

    return LibraryView;
});
