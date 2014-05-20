/*
*  This is the a view of an interface to search the problem library
*
*  
*/ 


define(['backbone', 'underscore','views/library-views/LibraryView','models/ProblemList','config','models/Problem'], 
function(Backbone, _, LibraryView,ProblemList,config,Problem){
    var LocalLibraryView = LibraryView.extend({
        className: "lib-browser",
    	initialize: function (options){
            //_.bindAll(this,"showResults","showProblems","buildMenu");
            _(this).bindAll("buildMenu");
            LibraryView.prototype.initialize.apply(this,[options]);
            this.libBrowserType = options.libBrowserType;
            this.libraryProblemsView.problems.type = "localLibrary";
            this.settings = options.settings;

    	},
        events: function(){
            return _.extend({},this.constructor.__super__.events,{
                "click .load-problems-button": "showProblems"
            });
        },
        render: function (){
            LibraryView.prototype.render.apply(this);


            if (this.libraryProblemsView.problems && this.libraryProblemsView.problems.size() >0){
                this.libraryProblemsView.renderProblems();
            } else { 
                this.$(".library-tree-container").html($("#loading-library-template").html());
                this.localProblems = new ProblemList();
                this.localProblems.type = this.libBrowserType;
                this.localProblems.fetch({success: this.buildMenu});
            }
            
            return this;
    	}, 
        showResults: function (data) {
            this.problemList = new ProblemList(data);
            this.showProblems();
        },
        showProblems: function (){
            var self = this;
            var dir = this.$(".local-library-tree-select").val() == "TOPDIR" ? "" : this.$(".local-library-tree-select").val();
            
            this.problemList = new ProblemList();
            this.localProblems.each(function(prob){
                var comps = prob.get("source_file").split("/");
                comps.pop();
                var topDir = comps.join("/");
                if( topDir==dir){
                    self.problemList.add(new Problem(prob.attributes),{silent: true});
                }
            });
            LibraryView.prototype.showProblems.apply(this);

        }, 
        buildMenu: function () {
            var _menu = [];
            this.localProblems.each(function(prob){
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
