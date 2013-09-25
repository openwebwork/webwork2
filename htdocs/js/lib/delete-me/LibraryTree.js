define(['Backbone', 'underscore','config'], function(Backbone, _,config){
	/**
	 *   The LibraryTree is a model of the entire WeBWorK library formed as a tree.
	 *
	 *   The tree consists of nested arrays.  
	 **/

	var LibraryTree = Backbone.Model.extend({

		initialize: function (){
            _.bindAll(this,"fetch","parsePathsToTree");
            this.fetched = false; 
		},
        fetch: function (){
            var self = this
              , requestObject = null;
            switch(this.get("type")){
            case "allLibraries":
                requestObject = {xml_command: "getProblemDirectories"};
                this.header = "Library/";
                break;
            case "allLibSubjects":
                //requestObject = {xml_command: "buildBrowseTree"};
                requestObject = {xml_command: "loadBrowseTree"};
                this.header = "Subjects/";
                break;
            case "localLibrary":
                requestObject = {xml_command: "loadLocalLibraryTree"};
                this.header = "LocalLibrary/";
                break;
            case "searchLibraries":
                
                break;
            }
            _.defaults(requestObject, config.requestObject);
            $.get(config.webserviceURL,requestObject,function(data){
                console.log("fetching the Library Tree");
                var response = $.parseJSON(data);
                switch(self.get("type")){
                case "allLibraries":
                    self.libs = response.result_data;
                    self.tree = self.parsePathsToTree(self.header);
                    delete self.libs;
                    break;
                case "allLibSubjects":
                    self.tree = response.result_data;
                    break;
                case "localLibrary":
                    self.libs = response.result_data.files;
                    self.tree = self.parsePathsToTree(self.header);
                    delete self.libs;
                    break;
                case "searchLibraries":
                    break;
                }
                self.fetched = true; 
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
                    tree.push({name: sp, subfields: ppp});
                } else {
                    tree.push({name: sp});
                }
            });

            return tree; 
        }




	});

	return LibraryTree;

});