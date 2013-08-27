/**
*  This view is the interface to the Library Tree and allows the user to easier navigate the Library. 
*
*/

define(['Backbone', 
    'underscore',
    '../models/LibraryTree'], 
function(Backbone, _,LibraryTree){
	
    var LibraryTreeView = Backbone.View.extend({
    	initialize: function (){
    		_.bindAll(this,"render","buildTreeView","updateLibraryTree","loadProblems");
            var self = this;
            this.parent = this.options.parent; 
            this.libraryTree = new LibraryTree({type: this.options.type});
            this.libraryTree.fetch();
            this.libraryTree.on("fetchSuccess", function () {
                self.$(".throbber").remove();
                self.buildTreeView(self.libraryTree.tree,0);
            });
    		this.render();



    	},
    	render: function(){
            this.$el.html(_.template($("#library-tree-template").html()));
    	},
        buildTreeView: function (libs,index){
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
            
        },
        loadProblems: function (evt) {
            console.log(evt);
            var path = _(this.$(".lib-select")).map(function(item){ return $(item).val()});
            if (this.$(".lib-select").last().val()==="Choose A Library") {path.pop();}
            this.parent.dispatcher.trigger("load-problems",this.libraryTree.header+path.join("/"));
        }


    });


    return LibraryTreeView;

});
