/*
*  This is the a view of a library (subject, directories, or local) typically within a LibraryBrowser view. 
*
*  
*/ 


define(['backbone', 'underscore','config', 'views/LibraryProblemsView','models/ProblemList','views/LibraryTreeView'], 
function(Backbone, _,config, LibraryProblemsView, ProblemList,LibraryTreeView){
    var LibraryView = Backbone.View.extend({
        className: "lib-browser",
    	initialize: function (options){
    		var self = this;
            _.bindAll(this,'addProblem','loadProblems','showProblems','changeDisplayMode');
            this.allProblemSets = options.problemSets;
            this.libBrowserType = options.libBrowserType;
            this.settings = options.settings;
            this.messageTemplate = options.messageTemplate;
            this.libraryProblemsView = new LibraryProblemsView({libraryView: this,
                 allProblemSets: this.allProblemSets, settings: this.settings});
            this.libraryTreeView = new LibraryTreeView({type: options.libBrowserType,allProblemSets: options.problemSets});
            this.libraryTreeView.libraryTree.on("library-selected", this.loadProblems);            

            
    	},
    	events: {   "change .target-set": "resetDisplayModes"
        }, 
    	render: function (){
            var modes = this.settings.getSettingValue("pg{displayModes}").slice(0); // slice makes a copy of the array.
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
        changeDisplayMode:function(evt){
            this.libraryProblemsView.changeDisplayMode(evt);
        },
        resetDisplayModes: function(){  // needed if there no target set was selected. 
            this.$('.target-set').css('background-color','white');
            this.$('.target-set').popover("hide");
        },
        setTargetSet: function(set){
            this.targetSet = set;
        },
        addProblem: function(model){
            var problemSet = this.allProblemSets.findWhere({set_id: this.targetSet});
            if(!problemSet){
                this.$(".target-set").css("background-color","rgba(255,0,0,0.4)")
                    .popover({placement: "bottom",content: this.messageTemplate({type:"select_target_set"})}).popover("show");
                return;
            }
            problemSet.addProblem(model);
        },
        showProblems: function () {
            this.$(".load-library-button").button("reset");  
            this.libraryProblemsView.set({problems: this.problemList, type:this.libBrowserType});
            this.libraryProblemsView.updatePaginator();
            this.libraryProblemsView.gotoPage(0);
        },
    	loadProblems: function (_path){   
            this.$(".load-library-button").button("loading"); 	
    		console.log(_path);
            var self = this;
			this.problemList = new ProblemList();
            this.problemList.path=_path;
            this.problemList.type = this.libBrowserType;
            this.problemList.fetch({success: this.showProblems});
    	}
    });

    return LibraryView;
});
