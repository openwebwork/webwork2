/*
*  This is the a view of a library (subject, directories, or local) typically within a LibraryBrowser view. 
*
*  
*/ 


define(['Backbone', 'underscore','config', 'views/LibraryProblemsView','models/ProblemList','views/LibraryTreeView'], 
function(Backbone, _,config, LibraryProblemsView, ProblemList,LibraryTreeView){
    var LibraryView = Backbone.View.extend({
        className: "lib-browser",
    	initialize: function (){
    		var self = this;
            _.bindAll(this,'addProblem','loadProblems','showProblems');
            this.allProblemSets = this.options.problemSets;
            this.errorPane = this.options.errorPane;
            this.libraryProblemsView = new LibraryProblemsView({libraryView: this,
                 allProblemSets: this.allProblemSets});
            this.libraryTreeView = new LibraryTreeView({type: this.options.libBrowserType, 
                                        allProblemSets: this.options.problemSets});
            this.libraryTreeView.libraryTree.on("library-selected", function(path) { self.loadProblems(path);});            

            
    	},
    	events: {   "change .target-set": "resetDisplayModes"
        }, 
    	render: function (){
            var modes = config.settings.getSettingValue("pg{displayModes}").slice(0); // slice makes a copy of the array.
            modes.push("None");
    		this.$el.html(_.template($("#library-view-template").html(), 
                    {displayModes: modes, sets: this.allProblemSets.pluck("set_id")}));
            this.libraryTreeView.setElement(this.$(".library-tree-container")).render();
            this.libraryProblemsView.setElement(this.$(".problems-container")).render();
            if (this.libraryProblemsView.problems && this.libraryProblemsView.problems.size() >0){
                this.libraryProblemsView.renderProblems();
            }
            return this;
    	},
        resetDisplayModes: function(){  // needed if there no target set was selected. 
            this.$('.target-set').css('background-color','white');
            this.$('.target-set').popover("hide");
        },
        addProblem: function(model){
            var targetSet = this.$(".target-set option:selected").val();
            var problemSet = this.allProblemSets.find(function(set) {return set.get("set_id")===targetSet});
            console.log(problemSet);
            if(!problemSet){
                this.$(".target-set").css("background-color","rgba(255,0,0,0.4)")
                    .popover({placement: "bottom",content: "You need to select a target set"}).popover("show");
                return;
            }
            problemSet.addProblem(model);
        },
        showProblems: function () {
            this.libraryProblemsView.set({problems: this.problemList, type:this.options.libBrowserType});
            this.libraryProblemsView.updatePaginator();
            this.libraryProblemsView.gotoPage(0);
        },
    	loadProblems: function (_path){    	
    		console.log(_path);
            var self = this;
			this.problemList = new ProblemList();
            this.problemList.path=_path;
            this.problemList.type = this.options.libBrowserType;
            this.problemList.fetch({success: this.showProblems});
    	}
    });

    return LibraryView;
});
