define(['backbone', 'underscore','views/library-views/LibraryView','views/library-views/LibraryTreeView'], 
function(Backbone, _,LibraryView,LibraryTreeView){
    var LibraryDirectoryView = LibraryView.extend({
        tabName: "By Directory",
    	initialize: function(options){
    		LibraryView.prototype.initialize.apply(this,[options]);
            var self = this;
            this.libraryTreeView = new LibraryTreeView({type: options.libBrowserType,allProblemSets: options.problemSets,
                topLevelNames: ["Select Library...","Select...","Select...","Select..."]});
            this.libraryTreeView.libraryTree.on("library-selected", this.loadProblems);
            Backbone.Validation.bind(this.libraryTreeView, {model: this.libraryTreeView.fields,
                invalid: function(view,attr,error){
                    view.$(".library-level-"+/level-(\d)-error/.exec(error)[1])
                        .popover({title: "Error", content: self.messageTemplate(
                            {type: error==="level-0-error"?"library_not_selected":"directory_not_selected"})})
                        .popover("show");
                }
            });
        },
    	loadProblems: function(_dirs){
           if(this.libraryTreeView.fields.validate()){
                console.log("Error!");
                return;
            } 
 
    		LibraryView.prototype.loadProblems.apply(this,[_dirs.join("/")]);
    	}


    });

    return LibraryDirectoryView;

});
