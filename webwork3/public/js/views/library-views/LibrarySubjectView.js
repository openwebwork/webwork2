define(['backbone', 'underscore','views/library-views/LibraryView','views/library-views/LibraryTreeView','bootstrap'], 
function(Backbone, _,LibraryView,LibraryTreeView){
    var LibrarySubjectView = LibraryView.extend({
    	initialize: function(options){
            var self = this;
    		LibraryView.prototype.initialize.apply(this,[options]);
            // Put the top level names in a template so it can be translated. 
            this.libraryTreeView = new LibraryTreeView({type: options.libBrowserType,allProblemSets: options.problemSets,
                topLevelNames: ["Select Subject...","Select Chapter...","Select Section...","Select..."]});
            this.libraryTreeView.libraryTree.on("library-selected", this.loadProblems);  
            Backbone.Validation.bind(this.libraryTreeView, {model: this.libraryTreeView.fields,
                invalid: function(view,attr,error){
                    view.$(".library-level-"+attr.split("level")[1])
                        .popover({title: "Error", content: self.messageTemplate({type: "library_not_selected"})})
                        .popover("show");
                }
            });          
    	},
    	loadProblems: function(_dirs){
            if(this.libraryTreeView.fields.validate()){
                console.log("Error!");
                return;
            } 
    		path = "";
    		if (_dirs[0]) {path += "/subjects/" + _dirs[0];}
	        if (_dirs[1]) {path += "/chapters/" + _dirs[1];}
            if (_dirs[2]) {path += "/sections/" + _dirs[2];}
    		LibraryView.prototype.loadProblems.apply(this,[path]);
    	}


    });

    return LibrarySubjectView;

});
