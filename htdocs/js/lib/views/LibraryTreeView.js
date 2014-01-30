/**
*  This view is the interface to the Library Tree and allows the user to more easier navigate the Library. 
*
*  To use the LibraryTreeView the following parameters are needed:
*  type:  the type of library needed which is passed to the Library Tree
*  
*
*/

define(['Backbone', 'underscore','models/LibraryTree','models/DBFields','stickit'], 
    function(Backbone, _,LibraryTree,DBFields){
	
    var LibraryTreeView = Backbone.View.extend({
    	initialize: function (options){
    		_.bindAll(this,"render","loadProblems","changeLibrary");
            var self = this;
            this.libraryTree = new LibraryTree({type: options.type});
            this.libraryTree.set("header","Library/");
            this.fields = new DBFields();
            this.fields.on("change",this.changeLibrary);
            this.subjects = [];
            this.chapters = [];
            this.sections = [];
    	},
    	render: function(){
            this.$el.html($("#library-tree-template").html());
            if (!this.libraryTree.get("tree")) {
                this.libraryTree.fetch({success: this.render});

            } else {
                this.$(".throbber").remove();

                if(this.subjects.length===0){
                    this.subjects = _(this.libraryTree.get("tree")).map(function(subj) {
                        return {label: subj.name, value: subj.name};
                    });                    
                }

                this.$(".library-tree-left").html($("#library-select-template").html());

                if(this.chapters.length>0){
                    this.$(".library-level-1").removeClass("hidden");
                }
                if(this.sections.length>0){
                    this.$(".library-level-2").removeClass("hidden");
                }
                this.stickit(this.fields, this.bindings);
            }
            
            return this; 
    	},
        events: {
                "click .load-library-button": "selectLibrary"},
        bindings: { ".library-level-0 select": {observe: "subject", selectOptions: {collection: "this.subjects",
                        defaultOption: {label: "Select...", value: null}}},
            ".library-level-1 select": {observe: "chapter", selectOptions: {collection: "this.chapters",
                        defaultOption: {label: "Select...", value: null}}},
            ".library-level-2 select": {observe: "section", selectOptions: {collection: "this.sections",
                        defaultOption: {label: "Select...", value: null}}}
        },
        changeLibrary: function(model){
            switch(_(model.changed).keys()[0]){
                case "subject":
                    this.$(".library-level-1").removeClass("hidden");
                    this.$(".library-level-2").addClass("hidden");
                    var selectedSubject = _(this.libraryTree.get("tree")).findWhere({name: this.fields.get("subject")});
                    this.chapters = _(selectedSubject.subfields).map(function(ch) { return {label: ch.name, value: ch.name};});
                    
                    this.$(".num-files").text(selectedSubject.num_files + " problems");
                    this.fields.set({chapter:"",section:""});
                    break;
                case "chapter":
                    this.$(".library-level-2").removeClass("hidden");
                    var selectedSubject = _(this.libraryTree.get("tree")).findWhere({name: this.fields.get("subject")});
                    var selectedChapter = _(selectedSubject.subfields).findWhere({name: this.fields.get("chapter")});
                    this.sections = _(selectedChapter.subfields).map(function(sect) { return {label: sect.name, value: sect.name};});
                    this.$(".num-files").text(selectedChapter.num_files + " problems");
                    this.fields.set({section:""});
                    break;
                case "section":
                    var selectedSubject = _(this.libraryTree.get("tree")).findWhere({name: this.fields.get("subject")});
                    var selectedChapter = _(selectedSubject.subfields).findWhere({name: this.fields.get("chapter")});
                    var selectedSection = _(selectedChapter.subfields).findWhere({name: this.fields.get("section")});
                    this.$(".num-files").text(selectedSection.num_files + " problems");
                break;

                
            }
            this.unstickit(this.fields);
            this.stickit(this.fields,this.bindings);
        },
        selectLibrary: function(evt){
            console.log("in LibraryTreeView.selectLibrary")
            var dirs = [];
            if(this.fields.get("subject")){dirs.push(this.fields.get("subject"))}
            if(this.fields.get("chapter")){dirs.push(this.fields.get("chapter"))}
            if(this.fields.get("section")){dirs.push(this.fields.get("section"))}
 
            this.libraryTree.trigger("library-selected",this.libraryTree.get("header")+ dirs.join("/"));
        },
        loadProblems: function (evt) {
            var path = _(this.$(".lib-select")).map(function(item){ return $(item).val()});
            if (this.$(".lib-select").last().val()==="Choose A Library") {path.pop();}
            this.parent.dispatcher.trigger("load-problems",this.libraryTree.header+path.join("/"));
        }


    });


    return LibraryTreeView;

});
