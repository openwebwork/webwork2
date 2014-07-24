define(['backbone', 'underscore','views/library-views/LibraryView','views/library-views/LibraryTreeView','bootstrap'], 
function(Backbone, _,LibraryView,LibraryTreeView){
    var LibrarySubjectView = LibraryView.extend({
        tabName: "By Subject",
    	initialize: function(options){
            var self = this;
    		LibraryView.prototype.initialize.apply(this,[options]);

            // Put the top level names in a template so it can be translated. 
            this.libraryTreeView = new LibraryTreeView({type: options.libBrowserType,allProblemSets: options.problemSets,
                topLevelNames: ["Select Subject...","Select Chapter...","Select Section...","Select..."]});
            this.libraryTreeView.libraryTree.on("library-selected", this.loadProblems);  
            
            // this ensures that the top level domain is selected. 
            Backbone.Validation.bind(this.libraryTreeView, {model: this.libraryTreeView.fields,
                invalid: function(view,attr,error){
                    view.$(".library-level-"+attr.split("level")[1])
                        .popover({title: "Error", content: self.messageTemplate({type: "library_not_selected"})})
                        .popover("show");
                }
            });        
    	}
    });

    return LibrarySubjectView;

});
