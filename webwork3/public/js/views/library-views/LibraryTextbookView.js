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

    });

    return LibraryTextbookView;
});
