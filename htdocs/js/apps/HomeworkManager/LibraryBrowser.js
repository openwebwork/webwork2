/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['Backbone', 'underscore','views/LibraryView','views/LibrarySearchView'], 
function(Backbone, _,LibraryView,LibrarySearchView){
    var LibraryBrowser = Backbone.View.extend({
        headerInfo: { template: "#libraryBrowser-header"}, 
    	initialize: function (){
    		var self = this; 
            _.bindAll(this,'render');
            _.extend(this,this.options);

            this.elements = {subjects: "library-subjects-tab",
                             directories: "library-directories-tab",
                             localLibrary: "library-local-tab",
                             search: "library-search-tab"};

            this.views = {
                subjects  :  new LibraryView({libBrowserType: "subjects", errorPane: this.hwManager.errorPane, 
                                            problemSets: this.hwManager.problemSets}),
                directories    :  new LibraryView({libBrowserType: "directories", errorPane: this.hwManager.errorPane, 
                                            problemSets: this.hwManager.problemSets}),
                localLibrary: new LibraryView({libBrowserType: "localLibrary", errorPane: this.hwManager.errorPane,
                                            problemSets: this.hwManager.problemSets}),
                search :  new LibrarySearchView({libBrowserType: "search", errorPane: this.hwManager.errorPane, 
                                            problemSets: this.hwManager.problemSets})
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
        }


    });

    return LibraryBrowser;
});
