define(['backbone', 'views/ProblemListView'], 
    function(Backbone, ProblemListView) {
    	var ProblemSetView = ProblemListView.extend({
            viewName: "Problems",
    		initialize: function (options) {
    			this.viewAttrs = {reorderable: true, showPoints: true, showAddTool: false, showEditTool: true,
                    showRefreshTool: true, showViewTool: true, showHideTool: false, deletable: true, draggable: false,
                    problem_seed: 1, show_undo: true};
                this.problemSet = options.problemSet;
                options.type = "problem_set";
                ProblemListView.prototype.initialize.apply(this,[options]);
    		},
            render: function () {
              ProblemListView.prototype.render.apply(this);  
              this.$(".prob-list-container").height($(window).height()-((this.maxPages==1) ? 200: 250));
            }
    	});

    	return ProblemSetView;
});
