/*
*  This is the a view of an interface to search the problem library
*
*  
*/ 


define(['Backbone', 'underscore','views/LibraryView','views/LibraryProblemsView','models/ProblemList'], 
function(Backbone, _,LibraryView, LibraryProblemsView,ProblemList){
    var LibrarySearchView = LibraryView.extend({
        className: "lib-browser",
    	initialize: function (){
            _.bindAll(this,"search","showResults","showProblems");
    		this.constructor.__super__.initialize.apply(this);
    	},
    	events: {"click .search-button": "search",
                    "change .target-set": "resetDisplayModes",
                    "click .load-more-btn": "loadMore"},
    	render: function (){
            var self = this;

    		this.$el.html(_.template($("#library-search-template").html(), {sets: this.allProblemSets.pluck("set_id")}));

    	},
        search: function () {
            var text = this.$(".search-text").val();
            var searchType = this.$(".search-option").val();
            console.log("I'm doing a " + searchType + " search for " + text + " in the library");
            var params = {};
            params[searchType] = text;

            $.get(config.urlPrefix + "library/problems", params, this.showResults);
        },
        showResults: function (data) {
            this.problemList = new ProblemList(data);
            this.showProblems();
        },
        showProblems: function (){
            (this.libraryProblemsView = new LibraryProblemsView({el: this.$(".lib-problem-viewer"), 
                                            type: "search",  
                                            problems: this.problemList})).render();

            this.problemList.on("add-to-target",this.addProblem);

        }
    });

    return LibrarySearchView;
});
