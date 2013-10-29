define(['Backbone', 'views/ProblemListView'], 
    function(Backbone, ProblemListView) {
    	var ProblemSetView = ProblemListView.extend({
    		initialize: function () {
    			this.headerTemplate = "#problem-set-header";
    			this.viewAttrs = {reorderable: true, showPoints: true, showAddTool: false, showEditTool: true,
                    showRefreshTool: true, showViewTool: true, showHideTool: false, deletable: true, draggable: false};
                this.problemSet = this.options.problemSet;
                this.options.type = "problem_set";
                this.constructor.__super__.initialize.apply(this);
    		},
            // setProblemSet: function(_set){
            //     this.problemSet = _set;
            // }
    	});


    	return ProblemSetView;
});
