/**
*  This view is the interface to the Library Tree and allows the user to more easier navigate the Library. 
*
*  To use the LibraryTreeView the following parameters are needed:
*  dispatcher:  A backbone Event dispatcher to send a event when a library is accessed.  
*  orientation: either "pulldown" (which produces a tree view) "horiztonal" or "vertical" (with selects) 
*  type:  the type of library needed which is passed to the Library Tree
*  
*
*/

define(['Backbone', 'underscore','models/LibraryTree'], function(Backbone, _,LibraryTree){
	
    var LibraryTreeView = Backbone.View.extend({
    	initialize: function (){
    		_.bindAll(this,"render","loadProblems");
            var self = this;
            this.orientation = this.options.orientation; // type of LibraryTreeView 
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
                //this.$(".dropdown-submenu a").truncate({width: 200});  // make sure the width of the library columns are too wide.
                //this.delegateEvents();
                /*var sel = this.$(".library-level-0").append("<option>Select</option>");

                _(this.libraryTree.get("tree")).each(function(leaf){
                    sel.append("<option>"+leaf.name+"</option>");
                }); */
            }
    	},
        events: {  "change .library-selector": "changeLibrary",
                "click .load-library-button": "selectLibrary"},
        changeLibrary: function(evt){
            var leaf = $(evt.target);
            switch(leaf.attr("id").split("-")[2]){
                case "0":
                    $("#library-level-1").removeClass("hidden");
                    $("#library-level-2").addClass("hidden");
                    var subfields = _(this.libraryTree.get("tree")).findWhere({name: leaf.val()}).subfields;
                    $("#library-level-1").html("<option>Select</option>" + 
                            _(subfields).map(function(sf) {return "<option>" + sf.name + "</option>";}).join(""));
                    break;
                case "1":
                    var subject = $("#library-level-0").val();
                    var chapter = $("#library-level-1").val();
                    $("#library-level-2").removeClass("hidden");
                    var allChapters = _(this.libraryTree.get("tree")).findWhere({name: subject}).subfields;
                    var allSections = _(allChapters).findWhere({name: chapter}).subfields;
                    $("#library-level-2").html("<option>Select</option>"+
                        _(allSections).map(function(sect){return "<option>" + sect.name + "</option>";}));
                break;

            }
        },
        selectLibrary: function(evt){
            var dirs = [];
            var subject = $("#library-level-0").val();
            var chapter = $("#library-level-1").val();
            var section = $("#library-level-2").val();

            for(i=0;i<3;i++){
                var sel = $("#library-level-"+i);
                var opt = $("#library-level-"+i + " option:selected");
                if( sel.val()&& opt.index()>0){ dirs.push(sel.val());}
            }

            this.libraryTree.trigger("library-selected",this.libraryTree.get("header")+ dirs.join("/"));
            
/*            return;
            if (leaf.text().trim() === "Library"){ return; }


            var path = leaf.text().trim();
            var level = parseInt(leaf.closest("li").data('level'));

            while(level>0){
                leaf = leaf.closest("li").parent().parent().children("a");
                path = leaf.text().trim() + "/" + path;
                level--;
            }

            

*/
            
        },
       /*  buildTreeView: function (libs,index){
            var self = this;
            var i;
            self.$(".throbber").remove();

            // remove other input item to the right of the selected one. 

            _(self.$(".lib-select")).each(function(item){
                var level = parseInt($(item).attr("id").split("-")[1],10);
                if (level >= index) {$(item).remove();}
            });

            self.$(".load-problems").remove();
            self.$(".load-problems").off("click");


            var opts = _(libs).map(function(lib){return "<option>" + (_.isArray(lib)?lib[0]:lib) + "</option>";});
            this.$(".library-tree-left").append("<select class='lib-select input-medium' id='ls-" + index + "'><option>Choose A Library</option>" 
                + opts.join("") + "</select>" + "<button class='load-problems btn btn-small'>Load Problems</button>");

            this.$(".lib-select").on("change",this.updateLibraryTree);
            this.$(".load-problems").on("click",self.loadProblems);


        },
        updateLibraryTree: function (evt) {
            var level = parseInt($(evt.target).attr("id").split("-")[1],10);  // the library level that was changed.  
            var i=0;
            var _tree = this.libraryTree.tree; 
            var buildTree = false; 
            while(i<=level){
                var selectedName = this.$("#ls-"+i).val();
                var index = _(_tree).map(function(item) { return (_.isArray(item)?item[0]:item);}).indexOf(selectedName);
                if (_.isArray(_tree[index])) {
                    buildTree = true;
                    _tree = _tree[index][1];
                } else { buildTree = false;}
                i++;

            }

            if (buildTree) {
                    this.buildTreeView(_tree,level+1);            
            }
            
        }, */
        loadProblems: function (evt) {
            var path = _(this.$(".lib-select")).map(function(item){ return $(item).val()});
            if (this.$(".lib-select").last().val()==="Choose A Library") {path.pop();}
            this.parent.dispatcher.trigger("load-problems",this.libraryTree.header+path.join("/"));
        }


    });


    return LibraryTreeView;

});
