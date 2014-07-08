/*
*  This is the a view of a library (subject, directories, or local) typically within a LibraryBrowser view. 
*
*  
*/ 

define(['backbone', 'underscore','config', 'views/library-views/LibraryProblemsView','models/ProblemList'], 
function(Backbone, _,config, LibraryProblemsView, ProblemList){
    var LibraryView = Backbone.View.extend({
        className: "library-view",
    	initialize: function (options){
    		var self = this;
            _.bindAll(this,'addProblem','loadProblems','showProblems','changeDisplayMode');
            this.allProblemSets = options.problemSets;
            this.libBrowserType = options.libBrowserType;
            this.settings = options.settings;
            this.eventDispatcher = options.eventDispatcher;
            this.messageTemplate = options.messageTemplate;
            this.rendered = false;
            this.libraryProblemsView = new LibraryProblemsView({libraryView: this, messageTemplate: this.messageTemplate,
                 allProblemSets: this.allProblemSets, settings: this.settings}); 
            this.libraryProblemsView.on("page-changed",function(num){
                self.eventDispatcher.trigger("save-state");
            }) 
    	},
    	events: {   
            "change .target-set": "resetDisplayModes"
        }, 
    	render: function (){
            var self = this;
            var modes = this.settings.getSettingValue("pg{displayModes}").slice(0); // slice makes a copy of the array.
            modes.push("None");
    		this.$el.html(_.template($("#library-view-template").html(), 
                    {displayModes: modes, sets: this.allProblemSets.pluck("set_id")}));
            if(this.libraryTreeView){
                this.libraryTreeView.setElement(this.$(".library-tree-container")).render();
                this.libraryTreeView.fields.on("change",function(model){
                    self.eventDispatcher.trigger("save-state");
                });
            }
            this.libraryProblemsView.setElement(this.$(".problems-container")).render();
            if (this.libraryProblemsView.problems && this.libraryProblemsView.problems.size() >0){
                this.libraryProblemsView.renderProblems();
            } else if(this.libraryProblemsView.problems && this.rendered){
                this.libraryTreeView.selectLibrary();
            }
            return this;
    	},
        getState: function (){
            return {fields: this.libraryTreeView ? this.libraryTreeView.fields.attributes : "", 
                rendered: this.rendered, pageNum: this.libraryProblemsView.currentPage};
        },
        setState: function(_state){
            if(_state && _state.fields){
                this.libraryTreeView.fields.set(_state.fields);
                this.rendered = _state.rendered;
                this.libraryProblemsView.currentPage = _state.pageNum;
            }
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
            this.libraryProblemsView.highlightCommonProblems();
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
            this.rendered = true;
            this.$(".load-library-button").button("reset");  
            this.libraryProblemsView.set({problems: this.problemList, type:this.libBrowserType})
                    .updatePaginator().gotoPage(this.libraryProblemsView.currentPage).highlightCommonProblems();
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
