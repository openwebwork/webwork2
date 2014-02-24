define(['backbone','config'], function(Backbone,config){
	/**
	 *   The LibraryTree is a model of the entire WeBWorK library formed as a tree.
	 *
	 *   The tree consists of nested arrays.  
	 **/

	var LibraryTree = Backbone.Model.extend({

		initialize: function(options){
			this.type = options.type;
		},

		url: function () {
            return config.urlPrefix + "Library/" + this.type;
        },
        parse: function(response){
        	var obj = {tree: response};
        	return obj;
        }
	});

	return LibraryTree;

});