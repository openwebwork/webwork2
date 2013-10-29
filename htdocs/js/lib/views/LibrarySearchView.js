/*
*  This is the a view of an interface to search the problem library
*
*  
*/ 


define(['Backbone', 'underscore','views/LibraryView','views/LibraryProblemsView','models/ProblemList','config'], 
function(Backbone, _,LibraryView, LibraryProblemsView,ProblemList,config){
    var LibrarySearchView = LibraryView.extend({
        className: "lib-browser",
    	initialize: function (){
            this.constructor.__super__.initialize.apply(this);
            _.bindAll(this,"search","showResults","checkForEnter");
            this.libraryProblemsView = new LibraryProblemsView({type: "search", libraryView: this, 
                                            allProblemSets: this.allProblemSets});
    	},
        events: function(){
            return _.extend({},LibraryView.prototype.events,{
                "click .search-button": "search",      
                "keyup .search-query": "checkForEnter"
            });
        },
    	render: function (){
            // var self = this;
            // var modes = config.settings.getSettingValue("pg{displayModes}").splice(0);
            // modes.push("None");
            this.$el.html($("#library-search-template").html());
            this.libraryProblemsView.setElement(this.$(".problems-container")).render();
            if(this.searchString){
                this.$(".search-query").val(this.searchString);
            }
            if(this.libraryProblemsView.problems){
                this.libraryProblemsView.renderProblems();
            }
            return this;
    	},
        search: function () {
            this.searchString = this.$(".search-query").val();
            var params = {};
            var searchTerms = this.searchString.split(/\s+and\s+/);
            _(searchTerms).each(function(term){
                var comps = term.split(":");
                params[comps[0]]=comps[1];
            });
            this.$(".search-button").button("loading");

            $.get(config.urlPrefix + "library/problems", params, this.showResults);
        },
        showResults: function (data) {
            this.$(".search-button").button("reset");
            this.problemList = new ProblemList(data);
            this.$(".num-problems").text(this.problemList.length + " problems");
            this.showProblems();
        },
        checkForEnter: function(evt){
            if (evt.keyCode==13){
                this.search();
                $(evt.target).blur();
            }
        }

    });

    return LibrarySearchView;
});
