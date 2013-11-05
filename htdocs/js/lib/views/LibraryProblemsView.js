define(['Backbone', 'views/ProblemListView','config'], 
    function(Backbone, ProblemListView,config) {
    	var LibraryProblemsView = ProblemListView.extend({
    		initialize: function () {
	            this.viewAttrs = {reorderable: false, showPoints: false, showAddTool: true, showEditTool: true,
                    showRefreshTool: true, showViewTool: true, showHideTool: true, deletable: false, draggable: true};
                this.allProblemSets = this.options.allProblemSets;
                this.libraryView = this.options.libraryView;
                this.type = this.options.type;
                this.constructor.__super__.initialize.apply(this); 
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
