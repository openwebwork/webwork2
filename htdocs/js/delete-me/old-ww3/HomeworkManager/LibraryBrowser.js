/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['Backbone', 'underscore','views/LibraryView','views/LibrarySearchView','views/LibraryProblemsView',
            'views/LocalLibraryView','views/LibraryTextbookView'], 
function(Backbone, _,LibraryView,LibrarySearchView,LibraryProblemsView,LocalLibraryView,LibraryTextbookView){
    var LibraryBrowser = Backbone.View.extend({
        
    	initialize: function (options){
    		var self = this; 
            _.bindAll(this,'render','updateNumberOfProblems');
            _.extend(this,options);

            this.activeView = "subjects";

            this.elements = {subjects: "library-subjects-tab",
                             directories: "library-directories-tab",
                             textbooks: "library-textbooks-tab",
                             localLibrary: "library-local-tab",
                             setDefinition: "set-definition-tab",
                             search: "library-search-tab"};


            //this.libraryProblemsView.on("update-num-problems",this.updateNumberOfProblems);

            this.views = {
                subjects  :  new LibraryView({libBrowserType: "subjects", problemSets: options.problemSets}),
                directories    :  new LibraryView({libBrowserType: "directories", problemSets: options.problemSets}),
                textbooks    :  new LibraryTextbookView({libBrowserType: "textbooks", problemSets: options.problemSets}),
                localLibrary: new LocalLibraryView({libBrowserType: "localLibrary", problemSets: options.problemSets}),
                setDefinition: new LocalLibraryView({libBrowserType: "setDefinition", problemSets: options.problemSets}),
                search :  new LibrarySearchView({libBrowserType: "search", problemSets: options.problemSets})
            };

            this.headerInfo = { template: "#libraryBrowser-header",
                events: {"show.bs.tab a[data-toggle='tab']": function(evt) { self.changeView(evt);} }};    
    	},
    	render: function (){
            var self = this; 
        	this.$el.html(_.template($("#library-browser-template").html()));
            _.chain(this.elements).keys().each(function(key){
                self.views[key].setElement(self.$("#"+self.elements[key]));
            });
            var index = _(_.keys(this.views)).indexOf(this.activeView);
            this.$("#library-browser-tabs li:eq(" + index + ") a").tab("show");
            this.views[this.activeView].render()
                .libraryProblemsView.on("update-num-problems",this.updateNumberOfProblems);
            this.problemSets.trigger("hide-show-all-sets","show");
    	},
        //events: {"shown a[data-toggle='tab']": "changeView"},
        changeView: function(evt){
            var self = this;
            var tabType = _(_(this.elements).invert()).pick($(evt.target).attr("href").substring(1)); // this search through the this.elements for selected tab
            var viewType = _(tabType).values()[0];
            this.activeView = viewType;
            //this.$("#library-browser-tabs li:eq(3) a").tab("show")
            _(_.keys(this.views)).each(function(view){
                self.views[view].libraryProblemsView.off("update-num-problems");
            })
            this.views[viewType].libraryProblemsView.on("update-num-problems",this.updateNumberOfProblems);
            this.views[viewType].render();
        },
        updateNumberOfProblems: function (text) {
            this.headerView.$(".number-of-problems").html(text);
        }
    });

    return LibraryBrowser;
});
