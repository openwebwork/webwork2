define(['Backbone', 'underscore','config'], function(Backbone, _,config){
	/**
	 *   The LibraryTree is a model of the entire WeBWorK library formed as a tree.
	 *
	 *   The tree consists of nested arrays.  
	 **/

	 // Does this need to be a Backbone model?  What does it gain us since there is no collection of trees.  

	var LibraryTree = Backbone.Model.extend({

		initialize: function (){
            _.bindAll(this,"fetch","parsePathsToTree");
			//console.log("LibraryTree");
		},
        fetch: function (){
            var self = this,
                requestObject = null;
            if (this.get("type") === "directory-tree"){
                requestObject = {xml_command: "getProblemDirectories"};
                this.header = "Library/";
            } else if (this.get("type") === "subject-tree"){
                requestObject = {xml_command: "buildBrowseTree"};
                this.header = "Subjects/";
            }
            _.defaults(requestObject, config.requestObject);
            $.get(config.webserviceURL,requestObject,function(data){
                console.log("fetching the Library Tree");
                var response = $.parseJSON(data);
                self.libs = response.result_data;
                self.tree = self.parsePathsToTree(self.header);
                delete self.libs;
             	self.trigger("fetchSuccess");
            });

        },
        parsePathsToTree: function(start){
            var self=this;
            var startPath = start.replace("(","\\(").replace(")","\\)");
            var regexp = new RegExp("^" + startPath.replace(/\//g,"\\/"));
            var stuff = _(self.libs).filter(function(lib) { return regexp.test(lib);});
            var paths = _(stuff).map( function(lib){ return (lib.split(regexp)[1])  });
            var subpaths = []; 

            _(paths).each(function(p,i){
                var pp = p.split("/");
                if ((p!=="") && (pp.length === 1)) {subpaths.push(pp[0]);}  // if the pathname is at the end. 
            });

            var tree = [] ;

            _(subpaths).each(function(sp){
                
                var ppp = self.parsePathsToTree(start+sp+"/");
                if (ppp && (ppp.length >0 )){
                    tree.push([sp, ppp]);
                } else {
                    tree.push(sp);
                }
            });

            return tree; 
        }




	});

	return LibraryTree;

});