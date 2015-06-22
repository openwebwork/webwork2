define(['backbone', 'views/ProblemListView'], 
    function(Backbone, ProblemListView) {
    	var ProblemSetView = ProblemListView.extend({
            viewName: "Problems",
    		initialize: function (options) {
    			this.viewAttrs = {reorderable: true, showPoints: true, showAddTool: false, showMaxAttempts: true,
                                  showEditTool: false, problem_seed: 1, showRefreshTool: true, 
                                  showViewTool: false, showHideTool: false, deletable: true, 
                                  draggable: false, show_undo: true, markCorrect: true};
                this.problemSet = options.problemSet;
                options.type = "problem_set";
                ProblemListView.prototype.initialize.apply(this,[options]);
                if(this.problemSet){
                    this.problemSet.on("change",function(m){
                        console.log(m.changed);
                    });
                }
                this.set({problem_set_view: this});
    		},
            render: function () {
              ProblemListView.prototype.render.apply(this);  
              this.$(".prob-list-container").height($(window).height()-((this.maxPages==1) ? 200: 250));
            },
            markAllCorrect: function(_model){
                console.log(_model.get("problem_id"));   
            }
    	});

    	return ProblemSetView;
});
