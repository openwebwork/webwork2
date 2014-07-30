define(['backbone', 'views/ProblemListView','config'], 
    function(Backbone, ProblemListView,config) {
    	var LibraryProblemsView = ProblemListView.extend({
    		initialize: function (options) {
                _(this).bindAll("highlightCommonProblems");
	            this.viewAttrs = {reorderable: false, showPoints: false, showAddTool: true, showEditTool: true, problem_seed: 1,
                    showRefreshTool: true, showViewTool: true, showHideTool: true, deletable: false, draggable: true};
                _.extend(this,_(options).pick("problemSets","libraryView","settings","type"));
                ProblemListView.prototype.initialize.apply(this,[options]); 
    		},
            render: function(){
                this.libraryView.libraryProblemsView.set({current_page: this.libraryView.tabState.get("page_num")});
                ProblemListView.prototype.render.apply(this);
                //this.libraryView.libraryProblemsView.set({current_page: this.libraryView.tabState.get("page_num")});
                this.libraryView.libraryProblemsView.on("page-changed",this.highlightCommonProblems);
                this.highlightCommonProblems();
                this.$(".prob-list-container").height($(window).height()-((this.maxPages==1) ? 200: 250));
                return this;
            },
            highlightCommonProblems: function () {
                var self = this;
                if(this.libraryView.targetSet){ 
                    var pathsInTargetSet = this.libraryView.problemSets.findWhere({set_id: this.libraryView.targetSet})
                        .problems.pluck("source_file");
                    var pathsInLibrary = this.problems.pluck("source_file");
                    var pathsInCommon = _.intersection(pathsInLibrary,pathsInTargetSet);
                    if(this.problemViews){
                        _(this.pageRange).each(function(i){
                            var pv = self.problemViews[i];
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
                return this;
            }
    	});

    	return LibraryProblemsView;
});
