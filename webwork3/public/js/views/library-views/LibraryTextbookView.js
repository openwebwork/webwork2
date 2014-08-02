// Note:  need to pull out tabName and topLevelNames into a template for I18N

define(['backbone', 'underscore','views/library-views/LibraryView','views/library-views/LibraryTreeView',
 'models/ProblemList','config'], 
function(Backbone, _,LibraryView,LibraryTreeView, ProblemList,config){
    var LibraryTextbookView = LibraryView.extend({
        className: "lib-browser",
        tabName: "Textbooks",
    	initialize: function (options){
            LibraryView.prototype.initialize.apply(this,[options]);
            this.libraryTreeView = new LibraryTreeView({type: options.libBrowserType,allProblemSets: options.problemSets,
                topLevelNames: ["Select Textbook...","Select Chapter...","Select Section...","Select..."]});
            this.libraryTreeView.libraryTree.on("library-selected", this.loadProblems);            
            _.bindAll(this,"loadProblems");
    	}
    });

    return LibraryTextbookView;
});
