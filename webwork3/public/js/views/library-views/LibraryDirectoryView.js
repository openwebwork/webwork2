define(['backbone', 'underscore','views/library-views/LibraryView','views/library-views/LibraryTreeView'], 
function(Backbone, _,LibraryView,LibraryTreeView){
    var LibraryDirectoryView = LibraryView.extend({
    	initialize: function(options){
    		LibraryView.prototype.initialize.apply(this,[options]);
            this.libraryTreeView = new LibraryTreeView({type: options.libBrowserType,allProblemSets: options.problemSets});
            this.libraryTreeView.libraryTree.on("library-selected", this.loadProblems);            
    	}


    });

    return LibraryDirectoryView;

});
