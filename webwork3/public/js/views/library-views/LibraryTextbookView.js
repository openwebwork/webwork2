define(['backbone', 'underscore','views/library-views/LibraryView','views/library-views/LibraryTreeView',
 'models/ProblemList','config'], 
function(Backbone, _,LibraryView,LibraryTreeView, ProblemList,config){
    var LibraryTextbookView = LibraryView.extend({
        className: "lib-browser",
    	initialize: function (options){
            LibraryView.prototype.initialize.apply(this,[options]);
            this.libraryTreeView = new LibraryTreeView({type: options.libBrowserType,allProblemSets: options.problemSets,
                topLevelNames: ["Select Textbook...","Select Chapter...","Select Section...","Select..."]});
            this.libraryTreeView.libraryTree.on("library-selected", this.loadProblems);            
            _.bindAll(this,"loadProblems");
    	},

        loadProblems: function(_path){

            // split the _path into title/author
            var title = _path[0].split(" - ")[0];
            var author = _path[0].split(" - ")[1];
            var path = "textbooks/author/" + author + "/title/" + title;
            var j;
            var sNames = ["chapter","section"]; 
            for(j=1;j<_path.length;j++){
                path += "/" + sNames[j-1] + "/" + _path[j];
            }
            path += "/problems";

            LibraryView.prototype.loadProblems.apply(this,[path])
        }

    });

    return LibraryTextbookView;
});
