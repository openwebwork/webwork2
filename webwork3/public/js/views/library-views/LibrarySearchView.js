/*
*  This is the a view of an interface to search the problem library
*
*  
*/ 


define(['backbone', 'underscore','views/library-views/LibraryView','models/ProblemList','config'], 
function(Backbone, _,LibraryView,ProblemList,config){
    var LibrarySearchView = LibraryView.extend({
        className: "lib-browser",
        tabName: "Search",
    	initialize: function (options){
            this.constructor.__super__.initialize.apply(this,[options]);
            _.bindAll(this,"search","showResults","checkForEnter");
    	},
        events: function(){
            return _.extend({},LibraryView.prototype.events,{
                "click .search-button": "search",      
                "keyup .search-query": "checkForEnter"
            });
        },
    	render: function (){
            this.$el.html($("#library-search-template").html());
            this.libraryProblemsView.setElement(this.$(".problems-container")).render();
            if(this.searchString){
                this.$(".search-query").val(this.searchString);
            }

            this.libraryProblemsView.render();

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
