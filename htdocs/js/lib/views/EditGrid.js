/** 
 * This is a superclass for any view that uses an editable grid. 
 *
 *
 */


define(['Backbone', 'underscore','editablegrid'], 
function(Backbone, _,EditableGrid){
	var EditGrid = Backbone.View.extend({
		initialize: function () {
			_.bindAll(this,"render","updatePaginator","changePage","showFirstPage","showPreviousPage",
					"showNextPage","showLastPage");
			this.grid = new EditableGrid(this.options.grid_name,this.options);
			this.paginator = this.options.paginator_name;
			this.grid.tableRendered = this.updatePaginator;

		},
		render: function () {
			var self = this;
			console.log("in EditGrid.render()");
            this.$el.html($(this.options.template_name).html());
          
            this.grid.renderGrid(this.options.table_name,"table table-bordered table-condensed","the_grid");
            this.grid.setPageIndex(0);


            return this;
 
		},
        events: {
	    "click .page-button": "changePage",
	    'click button.goto-first': "showFirstPage",
	    'click button.go-back-one' : "showPreviousPage",
	    'click button.go-forward-one': "showNextPage",
	    'click button.goto-end': "showLastPage",
		},
		updateGrid: function () {
			var self = this;
			if(this.grid.currentContainerid){
				this.grid.refreshGrid();
			}
			 // if it hasn't been rendered yet. 
			            // (pstaab)experiment here:
            // make a View for each row as a wrapper for Backbone.stickit

            
           /* this.rowViews = this.$("#the_grid tbody tr").map(function(i,_el){
            	return new EditGridRowView({el: null, bindings: self.options.bindings,
            			model: self.collection.get($(_el).attr("id").match(/(c\d+)/)[0])});
            }); */

		},
		updatePaginator: function () {

			var numPages = this.grid.getPageCount()
				, page = this.grid.getCurrentPageIndex()
				, pageStart = page < 10 ? 0 : page-10
				, pageEnd = numPages-page < 10 ? numPages : ((page<10) ? 20: page+10);
			$(this.paginator).empty()
				.html(_.template($("#paginator-template").html(),{page_start: pageStart, page_stop: pageEnd, num_pages: numPages}));
			this.$("button.page-button[data-page='" + page + "']").prop("disabled",true);
			if (page === 0) {
				this.$(".goto-first,.go-back-one").prop("disabled",true);
			} else if (page === numPages-1){
				this.$(".goto-end,.go-forward-one").prop("disabled",true);
			}
			this.delegateEvents();
		},
	    changePage: function (evt) {
			var newPageIndex = $(evt.target).data("page");
			this.grid.setPageIndex(newPageIndex);
			this.updatePaginator();
		},
		showFirstPage: function () {
			this.grid.setPageIndex(0);
			this.updatePaginator();
		},
		showPreviousPage: function (){
			var currentPage = this.grid.getCurrentPageIndex() -1 ;
			this.grid.setPageIndex(currentPage);
			this.updatePaginator();
		},
		showNextPage: function (){
			var currentPage = this.grid.getCurrentPageIndex() +1 ;
			this.grid.setPageIndex(currentPage);
			this.updatePaginator();	
		},
		showLastPage: function () {
			var lastIndex = this.grid.getPageCount()-1;
			this.grid.setPageIndex(lastIndex);
			this.updatePaginator();
		}



	});

	var EditGridRowView = Backbone.View.extend({
		initialize: function () {
			this.stickit(this.model,this.options.bindings);
		}
	});

	return EditGrid;


});