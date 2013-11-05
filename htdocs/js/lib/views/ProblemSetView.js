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
            render: function () {
              this.constructor.__super__.render.apply(this);  
              this.$(".prob-list-container").height($(window).height()-250);
            }
    	});

    	return ProblemSetView;
});
