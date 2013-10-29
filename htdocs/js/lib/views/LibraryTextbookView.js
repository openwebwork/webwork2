/*
*  This is the a view of an interface to search the problem library
*
*  
*/ 


define(['Backbone', 'underscore','views/LibraryView','views/LibraryProblemsView','models/ProblemList','config'], 
function(Backbone, _,LibraryView, LibraryProblemsView,ProblemList,config){
    var LibraryTextbookView = LibraryView.extend({
        className: "lib-browser",
    	initialize: function (){
            this.constructor.__super__.initialize.apply(this);
            _.bindAll(this,"showResults","loadProblems");
            this.libraryProblemsView = new LibraryProblemsView({type: "textbooks", libraryView: this, 
                                            allProblemSets: this.allProblemSets});
    	},
        events: function(){
            return _.extend({},LibraryView.prototype.events,{
                "change .textbook-title": "changeTextbook",
                "change .textbook-chapter": "changeChapter",
                "change .textbook-section": "changeSection",
                "click  .load-problems-button": "loadProblems"
            });
        },
    	render: function (){
            var self = this;
            var modes = config.settings.getSettingValue("pg{displayModes}").slice(0); // slice makes a copy of the array.
            modes.push("None");
            this.$el.html(_.template($("#library-view-template").html(), 
                    {displayModes: modes, sets: this.allProblemSets.pluck("set_id")}));
            //this.libraryTreeView.setElement(this.$(".library-tree-container")).render();
            this.libraryProblemsView.setElement(this.$(".problems-container")).render();
            if(this.textbooks){  // build the textbook tree
                this.buildTree();
            } else {
                this.fetchTextbooks();
            }
            if (this.libraryProblemsView.problems){
                this.libraryProblemsView.renderProblems();
            }
    	},
        buildTree: function () {
            this.$(".library-tree-container").html(_.template($("#library-textbooks-template").html()
                                ,{textbooks: this.textbooks}));
        },
        showResults: function (data) {
            //this.$(".search-button").button("reset");
            this.problemList = new ProblemList(data);
            this.$(".num-problems").text(this.problemList.length + " problems");
            this.showProblems();
        },
        fetchTextbooks: function () {
            var self = this;
            $.ajax({url:config.urlPrefix + "Library/textbooks", dataType: "json", success: function(data) {
                    console.log("received textbooks");
                    self.textbooks = data;
                    self.buildTree();
            }, error: function (XMLHttpRequest, textStatus, errorThrown) {
                console.log('error', textStatus, errorThrown);
            }});
        },
        changeTextbook: function(){
            this.$(".textbook-chapter").removeClass("hidden");
            this.$(".textbook-section").addClass("hidden");
            this.$(".textbook-chapter").html(_.template($("#library-textbook-sections-template").html(),
                {sections: this.textbooks[this.$(".textbook-title").index()].chapters, type: "Chapter"}));
        },
        changeChapter: function () {
            var textbookIndex = this.$(".textbook-title").index();
            var chapterIndex = this.$(".textbook-chapter").index();
            if(this.textbooks[textbookIndex].chapters[chapterIndex].sections){
                this.$(".textbook-section").removeClass("hidden");
                this.$(".textbook-section").html(_.template($("#library-textbook-sections-template").html(),
                    {sections: this.textbooks[textbookIndex].chapters[chapterIndex].sections, type: "Section"}));
            }
        },
        loadProblems: function () {
            var textbookID = this.$(".textbook-title").val();
            var chapterID = this.$(".textbook-chapter").val();
            var sectionID = this.$(".textbook-section").val();
            $.get(config.urlPrefix + "Library/textbooks/"+textbookID +"/chapters/" + chapterID 
                + "/sections/" + sectionID + "/problems",this.showResults);
        }


    });

    return LibraryTextbookView;
});
