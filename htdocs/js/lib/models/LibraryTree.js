define(['Backbone','config'], function(Backbone,config){
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
            return "/test/Library/" + this.type;
        },
        parse: function(response){
        	config.checkForError(response);
        	var obj = {tree: response};
        	return obj;
        }
	});

	return LibraryTree;

});