/**
*  This view is the interface to the Library Tree and allows the user to more easier navigate the Library. 
*
*  To use the LibraryTreeView the following parameters are needed:
*  type:  the type of library needed which is passed to the Library Tree
*  
*
*/

define(['backbone', 'underscore','models/LibraryTree','stickit','backbone-validation'], 
    function(Backbone, _,LibraryTree){
	
    var LibraryTreeView = Backbone.View.extend({
    	initialize: function (options){
    		_.bindAll(this,"render","loadProblems","changeLibrary");
            var self = this;
            this.libraryTree = new LibraryTree({type: options.type});
            this.libraryTree.set("header",options.type==="textbooks"?"textbooks/":"Library/");
            (this.fields = new LibraryLevels()).type = options.type;
            this.fields.on("change",this.changeLibrary);

            this.libraryLevel=[[],[],[],[]];
            this.bindings = {};
            for(var i = 0; i<4;i++) {
                this.bindings[".library-level-"+i+ " select"]= {observe: "level"+i,
                    selectOptions: {collection: function (view,opts) { 
                        return self.libraryLevel[opts.observe.split("level")[1]||""]},
                    defaultOption: {label: options.topLevelNames[i], value: ""}}};
            }
    	},
    	render: function(){
            var i,branch,numFiles = null;
            this.$el.html($("#library-tree-template").html());
            if (!this.libraryTree.get("tree")) {
                this.libraryTree.fetch({success: this.render});

            } else {
                this.$(".throbber").remove();
                if(this.libraryLevel[0].length===0){
                    this.libraryLevel[0] = _(this.libraryTree.get("tree")).map(function(subj) {
                        return {label: subj.name, value: subj.name};
                    });                    
                }

                this.$(".library-tree-left").html($("#library-select-template").html());

                for(i=1;i<4;i++){
                    if(this.libraryLevel[i].length>0){
                        this.$(".library-level-"+i).removeClass("hidden");
                    }
                }
                if(_(this.fields.values()).without("").length>0){
                    branch = this.branchOfTree(_(this.fields.attributes).values()); 
                    // the following needs to go into a template.
                    this.$(".load-library-button").text(branch.num_files? "Load " +branch.num_files + " problems": "Load");  
                }
                this.stickit(this.fields, this.bindings);
                this.changeLibrary(this.fields);
            }
            
            return this; 
    	},
        events: { "click .load-library-button": "selectLibrary"},
        changeLibrary: function(model){
            if(typeof(this.libraryTree.get("tree"))==="undefined" || _(model.changed).keys().length===0){
                return;
            }
            var keys = _(model.changed).keys();
            var last = keys[keys.length-1];
            var level = parseInt(last.split("level")[1]);
            var i;


            for(i=0;i<level+1;i++){
                var arr = _(model.attributes).values().slice(0,i+1);
                var branch = this.branchOfTree(arr);
                this.libraryLevel[i+1] = branch.branches;
            }

            for(i=0;i<4;i++){
                this.$(".library-level-"+i).addClass("hidden");  // hide all levels. 
            }
            for(i=0;i<level+2;i++){
                this.$(".library-level-"+i).removeClass("hidden");  // show needed levels.
            }

            this.$(".load-library-button").text(branch.num_files? "Load " +branch.num_files + " problems": "Load");  
            this.unstickit(this.fields);
            this.stickit(this.fields,this.bindings);
        },
        selectLibrary: function(evt){
            this.libraryTree.trigger("library-selected",_(this.fields.values()).without(""));
        },
        loadProblems: function (evt) {
            var path = _(this.$(".lib-select")).map(function(item){ return $(item).val()});
            if (this.$(".lib-select").last().val()==="Choose A Library") {path.pop();}
            this.parent.dispatcher.trigger("load-problems",this.libraryTree.header+path.join("/"));
        },
        branchOfTree: function(path){
            if(_(path).compact().length ===0){
                return {branches: []};
            }
            var currentBranch=this.libraryTree.get("tree");
            var numFiles;
            _(path).each(function(p,i){
                if(p.length>0){
                    var branch = _(currentBranch).findWhere({name:p});
                    currentBranch = branch.subfields;
                    numFiles = branch.num_files;
                }
            });
            return {branches: _(currentBranch).map(function(s) { return {label: s.name, value: s.name};}), 
                num_files: numFiles};
        }
    });

    var LibraryLevels = Backbone.Model.extend({
        defaults:  { 
            level0: "",
            level1: "",
            level2: "",
            level3: "",
        },
        validation: {
            level0: "checkLevel",
            level1: "checkLevel"
        },
        checkLevel: function() {
            if(this.type==="subjects" && this.get("level0")===""){
                return "Error!";
            } else if (this.type==="directories" && this.get("level0")===""){
                return "level-0-error";
            } else if (this.type==="directories" && this.get("level1")===""){
                return "level-1-error";
            }
        }
    });

    return LibraryTreeView;

});
