define(['Backbone', 'views/ProblemListView','config'], 
    function(Backbone, ProblemListView,config) {
    	var LibraryProblemsView = ProblemListView.extend({
    		initialize: function (options) {
	            this.viewAttrs = {reorderable: false, showPoints: false, showAddTool: true, showEditTool: true, problem_seed: 1,
                    showRefreshTool: true, showViewTool: true, showHideTool: true, deletable: false, draggable: true};
                this.allProblemSets = options.allProblemSets;
                this.libraryView = options.libraryView;
                this.type = options.type;
                this.constructor.__super__.initialize.apply(this,[options]); 
    		},
            render: function () {
                var modes = config.settings.getSettingValue("pg{displayModes}").slice(0);
                modes.push("None");
                this.$el.html(_.template($("#library-problems-view-template").html(),
                    {displayModes: modes, sets: this.allProblemSets.pluck("set_id")}));
                this.$(".display-mode-options").val(config.settings.getSettingValue("pg{options}{displayMode}")); 
                this.$(".prob-list-container").height($(window).height()-270);
                return this;
            },
    	});


    	return LibraryProblemsView;
});
