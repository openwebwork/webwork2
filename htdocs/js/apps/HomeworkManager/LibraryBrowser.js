/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['Backbone', 'underscore','views/LibraryView','views/LibrarySearchView','views/LibraryProblemsView'], 
function(Backbone, _,LibraryView,LibrarySearchView,LibraryProblemsView){
    var LibraryBrowser = Backbone.View.extend({
        headerInfo: { template: "#libraryBrowser-header"}, 
    	initialize: function (){
    		var self = this; 
            _.bindAll(this,'render','updateNumberOfProblems');
            _.extend(this,this.options);

            this.elements = {subjects: "library-subjects-tab",
                             directories: "library-directories-tab",
                             localLibrary: "library-local-tab",
                             search: "library-search-tab"};

            this.libraryProblemsView = new LibraryProblemsView();
            this.libraryProblemsView.on("update-num-problems",this.updateNumberOfProblems);

            this.views = {
                subjects  :  new LibraryView({libBrowserType: "subjects", errorPane: this.options.errorPane, 
                                            problemSets: this.options.problemSets,
                                            libraryProblemsView: this.libraryProblemsView}),
                directories    :  new LibraryView({libBrowserType: "directories", errorPane: this.options.errorPane, 
                                            problemSets: this.options.problemSets,
                                            libraryProblemsView: this.libraryProblemsView}),
                localLibrary: new LibraryView({libBrowserType: "localLibrary", errorPane: this.options.errorPane, 
                                            problemSets: this.options.problemSets,
                                            libraryProblemsView: this.libraryProblemsView}),
                search :  new LibrarySearchView({libBrowserType: "search", errorPane: this.options.errorPane, 
                                            problemSets: this.options.problemSets,
                                            libraryProblemsView: this.libraryProblemsView})
            }
    	},
    	render: function (){
            var self = this; 
        	this.$el.html(_.template($("#library-browser-template").html()));
            _.chain(this.elements).keys().each(function(key){
                self.views[key].setElement(self.$("#"+self.elements[key]));
            });
            this.views.subjects.render();
    	},
        events: {"shown a[data-toggle='tab']": "changeView"},
        changeView: function(evt){

            var tabType = _(_(this.elements).invert()).pick($(evt.target).attr("href").substring(1)); // this search through the this.elements for selected tab
            this.views[_(tabType).values()[0]].render();
        },
        updateNumberOfProblems: function (opts) {
            this.headerView.$(".number-of-problems").html(opts.number_shown + " of " +opts.total + " problems shown.");
            /*if(this.$(".prob-list li").length == this.problems.size()){
                this.$(".load-more-btn").addClass("disabled");
            } else {
                this.$(".load-more-btn").removeClass("disabled");
            }*/
        }, 



    });

    return LibraryBrowser;
});
