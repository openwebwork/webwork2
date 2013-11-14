define(['Backbone', 'views/ProblemListView'], 
    function(Backbone, ProblemListView) {
    	var ProblemSetView = ProblemListView.extend({
    		initialize: function (options) {
    			this.headerTemplate = "#problem-set-header";
    			this.viewAttrs = {reorderable: true, showPoints: true, showAddTool: false, showEditTool: true,
                    showRefreshTool: true, showViewTool: true, showHideTool: false, deletable: true, draggable: false,
                    problem_seed: 1};
                this.problemSet = options.problemSet;
                options.type = "problem_set";
                this.constructor.__super__.initialize.apply(this,[options]);
    		},
            render: function () {
              this.constructor.__super__.render.apply(this);  
              this.$(".prob-list-container").height($(window).height()-((this.maxPages==1) ? 200: 250));
            }
    	});

    	return ProblemSetView;
});
