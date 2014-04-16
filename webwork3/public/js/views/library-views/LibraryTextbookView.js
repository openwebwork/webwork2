define(['backbone', 'underscore','views/library-views/LibraryView','views/library-views/LibraryTreeView',
 'models/ProblemList','config'], 
function(Backbone, _,LibraryView,LibraryTreeView, ProblemList,config){
    var LibraryTextbookView = LibraryView.extend({
        className: "lib-browser",
    	initialize: function (options){
            LibraryView.prototype.initialize.apply(this,[options]);
            this.libraryTreeView = new LibraryTreeView({type: options.libBrowserType,allProblemSets: options.problemSets});
            this.libraryTreeView.libraryTree.on("library-selected", this.loadProblems);            
            _.bindAll(this,"loadProblems");
    	},
/*        events: function(){
            return _.extend({},LibraryView.prototype.events,{
                "change .textbook-title": "changeTextbook",
                "change .textbook-chapter": "changeChapter",
                "change .textbook-section": "changeSection",
                "click  .load-problems-button": "loadProblems"
            });
        }, */
/*    	render: function (){
            LibraryView.prototype.render.apply(this);
          /*  var self = this;
            var modes = this.settings.getSettingValue("pg{displayModes}").slice(0); // slice makes a copy of the array.
            modes.push("None");
            this.$el.html(_.template($("#library-view-template").html(), 
                    {displayModes: modes, sets: this.allProblemSets.pluck("set_id")}));
            this.$(".library-tree-container").html($("#library-loading-template"));
            this.libraryProblemsView.setElement(this.$(".problems-container")).render();
            if(this.textbooks){  // build the textbook tree
                this.buildTree();
            } else {
                this.fetchTextbooks();
            }
            if (this.libraryProblemsView.problems && this.libraryProblemsView.problems.size()>0){
                this.libraryProblemsView.renderProblems();
            } 
            return this;
    	}, */
        /*buildTree: function () {
            this.$(".library-tree-container").html(_.template($("#library-textbooks-template").html()
                                ,{textbooks: this.textbooks}));
        },
        showResults: function (data) {
            this.$(".load-problems-button").button("reset");
            this.problemList = new ProblemList(data);
            this.$(".num-problems").text(this.problemList.length + " problems");
            this.libraryProblemsView.set({problems: this.problemList, type:this.libBrowserType});
            this.libraryProblemsView.updatePaginator();
            this.libraryProblemsView.gotoPage(0);
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
            var textbookIndex = this.$(".textbook-title").val();
            this.$(".textbook-chapter").html(_.template($("#library-textbook-sections-template").html(),
                {sections: this.textbooks[textbookIndex].chapters, type: "Chapter"}));
            this.$(".textbook-message").html(this.textbooks[textbookIndex].num_probs + " problems available");
        },
        changeChapter: function () {
            var textbookIndex = this.$(".textbook-title").val();
            var chapterIndex = this.$(".textbook-chapter").val();
            this.$(".textbook-section").removeClass("hidden");
            this.$(".textbook-section").html(_.template($("#library-textbook-sections-template").html(),
                {sections: this.textbooks[textbookIndex].chapters[chapterIndex].sections, type: "Section"}));
            this.$(".textbook-message").html(this.textbooks[textbookIndex].chapters[chapterIndex].num_probs 
                    + " problems available");
        },
        changeSection: function () {
            var textbookIndex = this.$(".textbook-title").val();
            var chapterIndex = this.$(".textbook-chapter").val();
            var sectionIndex = this.$(".textbook-section").val();
            this.$(".textbook-message").html(this.textbooks[textbookIndex].chapters[chapterIndex].sections[sectionIndex].num_probs 
                    + " problems available");  
        },*/
        loadProblems: function(_path){
            var p = _path.split("/");
            // split the 2nd slot into title/author
            var title = p[1].split(" - ")[0];
            var author = p[1].split(" - ")[1];
            var path = p[0]+"/author/" + author + "/title/" + title;
            var j;
            var sNames = ["chapter","section"]; 
            for(j=2;j<p.length;j++){
                path += "/" + sNames[j-2] + "/" + p[j];
            }
            path += "/problems";

            LibraryView.prototype.loadProblems.apply(this,[path])
        }
        /*loadProblems: function () {
            this.$(".load-problems-button").button("loading");
            var textbookID = this.$(".textbook-title option:selected").data("id");
            var chapterID = this.$(".textbook-chapter option:selected").data("id");
            var sectionID = this.$(".textbook-section option:selected").data("id");
            var path = [];
            if(typeof(textbookID)=="undefined"){ // send an error

            } else if(typeof(chapterID)=="undefined"){
                $.get(config.urlPrefix + "Library/textbooks/"+textbookID + "/problems",this.showResults);
            } else if(typeof(sectionID)=="undefined"){
                $.get(config.urlPrefix + "Library/textbooks/"+textbookID+"/chapters/" + chapterID  + "/problems"
                    ,this.showResults);
            } else {
                $.get(config.urlPrefix + "Library/textbooks/"+textbookID +"/chapters/" + chapterID 
                    + "/sections/" + sectionID + "/problems",this.showResults);
            }
        } */


    });

    return LibraryTextbookView;
});
