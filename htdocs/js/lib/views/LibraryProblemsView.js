define(['Backbone', 'views/ProblemListView'], 
    function(Backbone, ProblemListView) {
    	var LibraryProblemsView = ProblemListView.extend({
    		initialize: function () {
    			this.headerTemplate = "#library-problems-header";
	            this.viewAttrs = {reorderable: false, showPoints: false, showAddTool: true, showEditTool: true,
                    showRefreshTool: true, showViewTool: true, showHideTool: true, deletable: false, draggable: true};

                this.libraryView = this.options.libraryView;
                this.options.type = "library";
                this.constructor.__super__.initialize.apply(this); 
    		}
    	});


    	return LibraryProblemsView;
});
