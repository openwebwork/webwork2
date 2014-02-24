/*
*  This is the a view of an interface to search the problem library
*
*  
*/ 


define(['backbone', 'underscore','views/LibraryView','views/LibraryProblemsView','models/ProblemList','config','models/Problem'], 
function(Backbone, _,LibraryView, LibraryProblemsView,ProblemList,config,Problem){
    var LocalLibraryView = LibraryView.extend({
        className: "lib-browser",
    	initialize: function (options){
            _.bindAll(this,"showResults","showProblems","buildMenu");
    		this.constructor.__super__.initialize.apply(this,[options]);
            this.libBrowserType = options.libBrowserType;
    	},
        events: function(){
            return _.extend({},this.constructor.__super__.events,{
                "click .load-problems-button": "showProblems"
            });
        },
    	render: function (){
            var modes = config.settings.getSettingValue("pg{displayModes}").slice(0); // slice makes a copy of the array.
            modes.push("None");
            this.$el.html(_.template($("#library-view-template").html(), 
                    {displayModes: modes, sets: this.allProblemSets.pluck("set_id")}));
            

            this.libraryProblemsView.setElement(this.$(".problems-container")).render();
            if (this.libraryProblemsView.problems && this.libraryProblemsView.problems.size() >0){
                this.libraryProblemsView.renderProblems();
            }
            this.$(".library-tree-container").html($("#loading-library-template").html());
            if(this.problemList){
                this.buildMenu();
            } else {
                this.problemList = new ProblemList();
                this.problemList.type = this.libBrowserType;
                this.problemList.fetch({success: this.buildMenu});
            }
            return this;
    	},
        showResults: function (data) {
            this.problemList = new ProblemList(data);
            this.showProblems();
        },
        showProblems: function (){

            var dir = this.$(".local-library-tree").val() == "TOPDIR" ? "" : this.$(".local-library-tree").val();
            
            var localProblems = new ProblemList();
            this.problemList.each(function(prob){
                var comps = prob.get("source_file").split("/");
                comps.pop();
                var topDir = comps.join("/");
                if( topDir==dir){
                    localProblems.add(new Problem(prob.attributes),{silent: true});
                }
            });
            this.libraryProblemsView.set({problems: localProblems, type:this.libBrowserType});
            this.libraryProblemsView.updatePaginator();
            this.libraryProblemsView.gotoPage(0);


        },
        buildMenu: function () {
            var _menu = [];
            this.problemList.each(function(prob){
                var comps = prob.get("source_file").split("/");
                comps.pop();
                _menu.push(comps.join("/"));
            })
            _menu = _(_menu).union(); // make the menu items unique.
            var index = _(_menu).indexOf("");
            if (index >-1){
                _menu[index]= "TOPDIR";
            }
            this.$(".library-tree-container").html(_.template($("#local-library-tree-template").html(),{menu: _menu}));
            this.delegateEvents();
        }
    });

    return LocalLibraryView;
});
