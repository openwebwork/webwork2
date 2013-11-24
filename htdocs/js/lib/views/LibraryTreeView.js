/**
*  This view is the interface to the Library Tree and allows the user to more easier navigate the Library. 
*
*  To use the LibraryTreeView the following parameters are needed:
*  type:  the type of library needed which is passed to the Library Tree
*  
*
*/

define(['Backbone', 'underscore','models/LibraryTree'], function(Backbone, _,LibraryTree){
	
    var LibraryTreeView = Backbone.View.extend({
    	initialize: function (){
    		_.bindAll(this,"render","loadProblems");
            var self = this;
            this.libraryTree = new LibraryTree({type: this.options.type});
            this.libraryTree.set("header","Library/");
    	},
    	render: function(){
            console.log("in LibraryTreeView.render()");
            this.$el.html($("#library-tree-template").html());
            if (!this.libraryTree.get("tree")) {
                this.libraryTree.fetch({success: this.render});

            } else {
                this.$(".throbber").remove();
                this.$(".library-tree-left").html(_.template($("#library-select-template").html(),
                        {subjects: this.libraryTree.get("tree")}));
                if(this.subject) {$("#library-level-0").val(this.subject);}
                if(this.chapter) {
                    this.changeLibrary("0",this.chapter);
                    this.$(".library-level-1").val(this.chapter);}
                if(this.section) {
                    this.changeLibrary("1",this.section);
                    this.$(".library-level-2").removeClass("hidden").val(this.section);}
            }
            return this; 
    	},
        events: {  "change .library-selector": "changeLibrary",
                "click .load-library-button": "selectLibrary"},
        changeLibrary: function(arg1,arg2){
            var level = (typeof(arg1)=="string")? parseInt(arg1) : parseInt($(arg1.target).data("level"));
            var name = (typeof(arg2)=="string")? arg2: $(arg1.target).val();
            switch(level){
                case 0:
                    var subject = this.$(".library-level-0").val() || this.subject;
                    this.$(".library-level-1").removeClass("hidden");
                    this.$(".library-level-2").addClass("hidden");
                    var allChapters = _(this.libraryTree.get("tree")).findWhere({name: subject});
                    this.$(".library-level-1").html("<option>Select</option>" + 
                            _(allChapters.subfields).map(function(sf) {return "<option>" + sf.name + "</option>";}).join(""));
                    this.$(".num-files").text(allChapters.num_files + " problems");
                    break;
                case 1:
                    var subject = this.$(".library-level-0").val() || this.subject;
                    var chapter = this.$(".library-level-1").val() || this.chapter;
                    this.$(".library-level-2").removeClass("hidden");
                    var allChapters = _(this.libraryTree.get("tree")).findWhere({name: subject});
                    var allSections = _(allChapters.subfields).findWhere({name: chapter});
                    this.$(".library-level-2").html("<option>Select</option>"+
                        _(allSections.subfields).map(function(sect){return "<option>" + sect.name + "</option>";}));
                    this.$(".num-files").text(allSections.num_files + " problems");
                case 2:
                    var subject = this.$(".library-level-0").val() || this.subject;
                    var chapter = this.$(".library-level-1").val() || this.chapter;
                    var section = this.$(".library-level-2").val() || this.section;
                    var allChapters = _(this.libraryTree.get("tree")).findWhere({name: subject});
                    var allSections = _(allChapters.subfields).findWhere({name: chapter});
                    var selectedSection = _(allSections.subfields).findWhere({name: section});
                    this.$(".num-files").text(selectedSection.num_files + " problems");
                break;

            }
        },
        selectLibrary: function(evt){
            console.log("in LibraryTreeView.selectLibrary")
            var dirs = [];
            this.subject = this.$(".library-level-0").val();
            this.chapter = this.$(".library-level-1").val();
            this.section = this.$(".library-level-2").val();

            for(i=0;i<3;i++){
                var sel = this.$(".library-level-"+i);
                var opt = this.$(".library-level-"+i + " option:selected");
                if( sel.val()&& opt.index()>0){ dirs.push(sel.val());}
            }

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
