define(['backbone', 'views/ProblemListView','config'], 
    function(Backbone, ProblemListView,config) {
    	var LibraryProblemsView = ProblemListView.extend({
    		initialize: function (options) {
	            this.viewAttrs = {reorderable: false, showPoints: false, showAddTool: true, showEditTool: true, 
                    problem_seed: 1, showRefreshTool: true, showViewTool: true, showHideTool: true, 
                    deletable: false, draggable: true, show_undo: false};
                _.extend(this,_(options).pick("problemSets","libraryView","settings","type"));
                this.libraryView = options.libraryView;
                ProblemListView.prototype.initialize.apply(this,[options]); 
    		},
            render: function(){
                  ProblemListView.prototype.render.apply(this);
                  this.highlightCommonProblems();
                  this.$(".prob-list-container").height($(window).height()-((this.maxPages==1) ? 200: 250))
            },
            highlightCommonProblems: function () {
                var self = this;
                if(this.libraryView.targetSet){ 
                    var pathsInTargetSet = this.libraryView.problemSets.findWhere({set_id: this.libraryView.targetSet})
                        .problems.pluck("source_file");
                    var pathsInLibrary = this.problems.pluck("source_file");
                    var pathsInCommon = _.intersection(pathsInLibrary,pathsInTargetSet);
                    _(self.problemViews).each(function(pv,i){
                        if(pv.rendered){
                            pv.highlight(_(pathsInCommon).contains(pathsInLibrary[i]));
                        } else {
                            pv.model.once("rendered", function(v) {
                                v.highlight(_(pathsInCommon).contains(pathsInLibrary[i]));
                            });
                        }
                    });
                }
            }
    	});

    	return LibraryProblemsView;
});
