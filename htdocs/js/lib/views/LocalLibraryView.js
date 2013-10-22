/*
*  This is the a view of an interface to search the problem library
*
*  
*/ 


define(['Backbone', 'underscore','views/LibraryView','views/LibraryProblemsView','models/ProblemList','config','models/Problem'], 
function(Backbone, _,LibraryView, LibraryProblemsView,ProblemList,config,Problem){
    var LocalLibraryView = LibraryView.extend({
        className: "lib-browser",
    	initialize: function (){
            _.bindAll(this,"showResults","showProblems","buildMenu");
    		this.constructor.__super__.initialize.apply(this);
            this.type = this.options.libBrowserType;
    	},
    	events: {"click .load-problems-button": "showProblems",
                    "change .target-set": "resetDisplayModes",
                    "click .load-more-btn": "loadMore"},
    	render: function (){
            var self = this;
            var modes = config.settings.getSettingValue("pg{displayModes}");
            modes.push("None");
            this.$el.html(_.template($("#library-view-template").html(), 
                    {displayModes: modes, sets: this.allProblemSets.pluck("set_id")}));
            this.$(".library-tree-container").html("Loading Library...<i class='icon-spinner icon-spin'></i>");
            if(this.problemList){
                this.showProblems();
            } else {
                this.problemList = new ProblemList();
                this.problemList.type = this.type;
                this.problemList.fetch({success: this.buildMenu});
            }
    	},
        showResults: function (data) {
            this.problemList = new ProblemList(data);
            this.showProblems();
        },
        showProblems: function (){

            var dir = $(".local-library-tree").val() == "TOPDIR" ? "" : $(".local-library-tree").val();
            
            var localProblems = new ProblemList();
            this.problemList.each(function(prob){
                var comps = prob.get("source_file").split("/");
                comps.pop();
                var topDir = comps.join("/");
                if( topDir==dir){
                    localProblems.add(new Problem(prob.attributes),{silent: true});
                }
            })

            console.log(localProblems);
            (this.libraryProblemsView = new LibraryProblemsView({el: this.$(".lib-problem-viewer"), 
                                            type: "local",  
                                            problems: localProblems})).render();

            //this.problemList.on("add-to-target",this.addProblem);

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
