/*
*  This is the a view of a library (subject, directories, or local) typically within a LibraryBrowser view. 
*
*  
*/ 


define(['Backbone', 'underscore','views/LibraryProblemsView','models/ProblemList','views/LibraryTreeView'], 
function(Backbone, _,LibraryProblemsView, ProblemList,LibraryTreeView){
    var LibraryView = Backbone.View.extend({
        className: "lib-browser",
    	initialize: function (){
    		var self = this; 
            _.bindAll(this,'render','showProblems','addProblem');
            this.allProblemSets = this.options.problemSets;
            this.errorPane = this.options.errorPane;
            this.libraryProblemsView = this.options.libraryProblemsView;
            
    		//this.dispatcher.on("load-problems", function(path) { self.loadProblems(path);});

            // The following needs to be changed it's being called when the problem set list is shown.  

            
            this.libraryTreeView = new LibraryTreeView({dispatcher: this.dispatcher, orientation: "dropdown", 
                                            type: this.options.libBrowserType});
            this.libraryTreeView.libraryTree.on("library-selected", function(path) { self.loadProblems(path);});            

            
    	},
    	events: {//"change #library-selector": "changeView",
                    "change .target-set": "resetDisplayModes",
                    "click .load-more-btn": "loadMore"
        },
    	render: function (){
            var self = this;

    		this.$el.html(_.template($("#library-view-template").html(), {sets: this.allProblemSets.pluck("set_id")}));
            this.libraryProblemsView.setElement(this.$(".lib-problem-viewer"));
            this.libraryTreeView.render();
            this.$(".library-viewer").append(this.libraryTreeView.el);
    		this.$(".lib-problem-viewer").height(0.8*screen.height);  // make sure that the view is tall enough to view the library
    		//this.showProblems();
    	},
        loadMore: function () {
            this.libraryProblemsView.loadMore();
        },
        showProblems: function (){
            console.log("in showProblems");
            console.log(this.problemList);
            this.libraryProblemsView.setProblems(this.problemList,this.options.libBrowserType);
            this.libraryProblemsView.render();
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
    	/*changeView: function (evt) {
    		var self = this;
            $(".lib-problem-viewer").html("");

    	}, */
    	loadProblems: function (_path){    	
    		console.log(_path);
            var self = this;
			this.problemList = new ProblemList();
            this.problemList.path=_path;
            this.problemList.type = this.options.libBrowserType;
            this.problemList.fetch({success: this.showProblems});
    	}, 
        resetDisplayModes: function(){
            this.$('.target-set').css('background-color','white');
        }

    });

    return LibraryView;
});
