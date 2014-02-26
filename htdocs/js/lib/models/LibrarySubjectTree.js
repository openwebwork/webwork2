define(['Backbone','config'], function(Backbone,config){
	/**
	 *   The LibraryTree is a model of the entire WeBWorK library formed as a tree.
	 *
	 *   The tree consists of nested arrays.  
	 **/

	var LibrarySubjectTree = Backbone.Model.extend({

		initialize: function(options){
			this.type = options.type;
		}

		url: function () {
            return config.urlPrefix + "library/" + this.type;
        },
        parse: function(response){
        	config.checkForError(response);
        	return response;
        }
	});