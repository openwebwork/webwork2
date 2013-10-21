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
            _.bindAll(this,'render','showProblems','addProblem');
            this.allProblemSets = this.options.problemSets;
            this.errorPane = this.options.errorPane;
            this.libraryProblemsView = new LibraryProblemsView({libraryView: this});
            this.libraryTreeView = new LibraryTreeView({type: this.options.libBrowserType});
            this.libraryTreeView.libraryTree.on("library-selected", function(path) { self.loadProblems(path);});            

            
    	},
    	events: {"change .target-set": "resetDisplayModes",
                    "click .load-more-btn": "loadMore",
                    "change .display-mode-options": "changeDisplayMode"
        },
    	render: function (){
            var modes = config.settings.getSettingValue("pg{displayModes}");
            modes.push("None");
    		this.$el.html(_.template($("#library-view-template").html(), 
                    {displayModes: modes, sets: this.allProblemSets.pluck("set_id")}));
            this.libraryTreeView.setElement(this.$(".library-tree-container")).render();
            this.libraryProblemsView.setElement(this.$(".lib-problem-viewer")).render();
    	},
        loadMore: function () {
            this.libraryProblemsView.loadMore();
        },
        showProblems: function (){
            console.log("in showProblems");
            this.libraryProblemsView.set({problems: this.problemList,type: this.options.libBrowserType,
                displayMode: this.$(".display-mode-options").val()});
            this.libraryProblemsView.render();
        },
        changeDisplayMode: function () {
            this.problemList.each(function(problem){
                problem.set({data: null, displayMode: self.$(".display-mode-options").val()},{silent:true});
            });
            this.showProblems();
        },
        addProblem: function(model){
            var targetSet = this.$(".target-set option:selected").val();
            var problemSet = this.allProblemSets.find(function(set) {return set.get("set_id")===targetSet});
            console.log(problemSet);
            if(!problemSet){
                this.$(".target-set").css("background-color","rgba(255,0,0,0.4)")
                    .popover({placement: "top",content: "You need to select a target set"}).popover("show");
                return;
            }
            problemSet.addProblem(model);
        },
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
