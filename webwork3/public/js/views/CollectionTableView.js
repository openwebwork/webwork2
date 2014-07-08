/**
 * 
 *  A backbone view replacement for editable grid
 *
 *  A collection must be passed into the constructor. Also with an array of Column names. 
 * The following must also be passed into the View:
 *  
 * columnInfo:  An array of {name: _name, key: _key, editable: boolean, classnames: _classnames,
 		datatype: _datatype, binding: _binding} where 
 	-  _name will be the header of the column
 	-  _key is the field name of the model 
 	-  _editable is a boolean for whether or not the column is editable
 	-  _classnames will assign the td element in the table those classnames.  It can be either a string or an
 			array of strings.
 	-  _datatype will be the type of data for the column.  This is important for sorting.
 	-  _use_contenteditable: boolean  (this uses the contenteditable attribute whenever a column is editable. Set to 
 	         false if you don't want to use this or true or nothing to use it.)
 	-  _stickit_options: is an stickit bindings object.  You don't need to define observe because the classname will 
 	        be passed in.
 	-  _sortFxn: is a function that returns a value to be sorted on.   


Other options:
	pageSize: the number of rows in a visible table (or -1 for all rows shown.)


Sorting: 
   The table will sort unless the datatype field is not set.  It will sort both ascending and descending. 
   Currently only "integer" and "string" data is set. 
   If you want to sort on a different piece of data, you need to specify the key (field) where the data is stored. 
 */


define(['backbone', 'underscore','stickit'], function(Backbone, _){

	var CollectionTableView = Backbone.View.extend({
		tagName: "table",
		className: "collection-table",
		initialize: function (options) {
			var self = this;
			_.bindAll(this,"render","sortTable","filter");
			this.collection = options.collection;
			this.filteredCollection = [];
			this.showFiltered = false;
			this.columnInfo = options.columnInfo;
			this.paginatorProp = options.paginator;
			this.tableClasses = options.classes; 
			this.setColumns(options.columnInfo);
			if($(options.tablename).length>0){ // if the tablename was passed use it as the $el
				this.$el=$(options.tablename);
			}
			if(typeof(options.paginator.showPaginator)==="undefined"){
				this.paginatorProp.showPaginator = true;	
			}
			// setup the paginator 
			this.initializeTable();
		},
		initializeTable: function () {

			this.pageSize =  (this.paginatorProp && this.paginatorProp.page_size)? this.paginatorProp.page_size: 
				this.collection.size();
			this.pageRange = this.pageSize > 0 ?  _.range(this.pageSize) : _.range(this.collection.length) ;
			this.currentPage = 0;
			this.rowViews = [];
			this.$el.addClass(this.tableClasses);

			this.sortInfo = {};  //stores the sort column and sort direction
		},
		setColumns: function(columnInfo){
			var self = this;
			this.columnInfo = columnInfo;
			this.bindings = {};
			_(this.columnInfo).each(function(col){ 
				var obj = {};
				obj["."+col.classname] = {observe: col.key}; // set it up for stickit format
				
				if(typeof col.use_contenteditable == 'undefined'){ col.use_contenteditable=true;}
				if(typeof col.stickit_options != 'undefined'){
					_.extend(obj["."+col.classname],col.stickit_options);
					col.use_contenteditable = col.editable;
				}
				if(col.value && _.isFunction(col.value)) { // then the value is calculated.
					self.collection.each(function(_model){
						if(!_model._extra){
							_model._extra= {};
						}
						_model._extra[col.key]=col.value.apply(this,[_model]);
					})
				}
				_.extend(self.bindings, obj);
			});
			return this;
		},
		render: function () {
			var self = this, i;
			this.$el.empty();

			// set up the HTML for the table header
			var headRow = $("<tr>");
			var tbody = $("<tbody>");
			this.$el.append($("<thead>").append(headRow)).append(tbody);

			_(this.columnInfo).each(function (col){
				var className = _.isArray(col.classname)?col.classname[0] : col.classname;
				var th = $("<th data-class-name='" + className + "'>").addClass(className)
					.html(col.colHeader? col.colHeader: col.name + "<span class='sort'></span>");
				headRow.append(th);
				// if(col.colHeader){

				// 	headRow.append("<th data-class-name='" + className + "'>" + col.colHeader + "<span class='sort'></span></th>");
				// } else {
				// 	headRow.append("<th data-class-name='" + className + "'>" + col.name + "<span class='sort'></span></th>");
				// }
			});

			this.updateTable();
			if(this.pageSize >0){
				for(i=0;i<this.pageSize;i++){
					if(this.rowViews[i]){
						tbody.append(self.rowViews[i].render().el);
					}
				}
			} else {
				_(this.rowViews).each(function(row){
					tbody.append(row.render().el);
				});
			}

			if(this.paginatorProp.showPaginator){
				this.$el.append($("<tr class='paginator-row'>"));
				this.updatePaginator();
			}

			if(this.sortInfo){
				this.$("th[data-class-name='"+ this.sortInfo.classname+ "'] .sort")
					.html("<i class='fa fa-long-arrow-" + (this.sortInfo.direction >0 ? "down": "up") + "'></i>" );
			}

			return this;
		},
		updatePaginator: function() {
			// render the paginator

			if (this.showFiltered){
				this.maxPages = Math.ceil(this.filteredCollection.length/this.paginatorProp.page_size);
			} else {
				this.maxPages = Math.ceil(this.collection.length / this.paginatorProp.page_size);
			}

			var cell = $("<div>")
				, i
				, start =0
                , stop = this.maxPages;
            
            if(this.maxPages>15){
                start = (this.currentPage-7 <0)?0:this.currentPage-7;
                stop = start+15<this.maxPages?start+15 : this.maxPages;
            }
			cell.append("<button class='paginator-page first-page'>&lt;&lt;</button>");
			cell.append("<button class='paginator-page prev-page'>&lt;</button>");
			if(start>0){
				cell.append("<button class='paginator-page' disabled='disabled'>...</button>");
			}
			for(i=start;i<stop;i++){
				cell.append("<button class='paginator-page numbered-page' data-page-num='"+i+"'>"+(i+1)+"</button>");
			}
			if(stop<this.maxPages){
				cell.append("<button class='paginator-page' disabled='disabled'>...</button>");
			}
			cell.append("<button class='paginator-page next-page'>&gt;</button>");
			cell.append("<button class='paginator-page last-page'>&gt;&gt;</button>");
			var td = $("<td>").attr("colspan",this.columnInfo.length);
			td.append(cell).css("text-align","center");

			this.$(".paginator-row").html(td);


			if(this.paginatorProp.button_class){
				this.$(".paginator-page").addClass(this.paginatorProp.button_class);
			}
			if(this.paginatorProp.row_class){
				this.$(".paginator-row div").addClass(this.paginatorProp.row_class);
			}

			this.$(".paginator-row button").removeClass("current-page");
			this.$(".numbered-page[data-page-num='"+this.currentPage+"']").addClass("current-page");

			if(stop===1){
				this.$(".paginator-row").addClass("hidden")
			} else {
				this.$(".paginator-row").removeClass("hidden")
			}
			this.delegateEvents();
		},
		filter: function(filterText) {
			if(this.currentPage != 0){
				this.gotoPage(0);
			}
			var filterText;
			if(filterText===""){
				this.showFiltered = false;
				return this;
			}
			if(_(filterText).isObject()){
				this.filteredCollection =this.collection.where(filterText);
			} else {
				filterRE = new RegExp(filterText,"i");
				this.filteredCollection = this.collection.filter(function(model){
					return _(model.attributes).values().join(";").search(filterRE) > -1;
				});
			}
			this.showFiltered = true;
			return this;
		},
		set: function(options){
			if(options.num_rows){
				this.paginatorProp.page_size = options.num_rows;
				this.initializeTable();
				this.updatePaginator();
				this.render();
			}
		},
		updateTable: function () {
			var self = this;
			this.rowViews = [];
			_(this.pageRange).each(function(i,j){
				if(self.showFiltered){ 
					if(self.filteredCollection[i]){
						self.rowViews[j] = new TableRowView({model: self.filteredCollection[i],columnInfo: self.columnInfo,
							bindings: self.bindings});
					}
				} else {
					if(self.collection.at(i)){
						self.rowViews[j]=new TableRowView({model: self.collection.at(i),columnInfo: self.columnInfo, 
							bindings: self.bindings});
					}
				}
			});
		},
		refreshTable: function (){
			_(this.rowViews).each(function(row){row.refresh();});
		},
		getRowCount: function () {
			return (this.showFiltered)? this.filteredCollection.length : this.collection.length;
		},
		events: {"click th": "sortTable",
				"click .first-page": "firstPage",
				"click .prev-page": "prevPage",
				"click .numbered-page": "gotoPage",
				"click .next-page": "nextPage",
				"click .last-page": "lastPage",
				"click button.paginator-page": "pageChanged"
		},
		sortTable: function(evt){
			var self = this;
			var sort = _(this.columnInfo).find(function(col){
				return (_.isArray(col.classname)? col.classname[0] : col.classname ) == $(evt.target).data("class-name");
			});
			
			if(typeof(sort)=="undefined"){ // The user clicked on the select all button.
				return;
			}

			if(this.sortInfo && this.sortInfo.key==sort.key){
				this.sortInfo.direction = -1*this.sortInfo.direction;
			} else {
				this.sortInfo = {key: sort.key, direction: 1, 
						classname: _.isArray(sort.classname)? sort.classname[0] : sort.classname};
			}
			// determine the sort Function

			var sortFunction = sort.sort_function || function(val) { return val;};

			if(typeof(sort.datatype)==="undefined"){
				console.error("You need to define a datatype to sort");
				return;
			}

			/* Need a more robust comparator function. */
			this.collection.comparator = function(model1,model2) { 
				var value1 = typeof(model1.get(sort.key)) === "undefined" ? model1._extra[sort.key] : model1.get(sort.key);
				var value2 = typeof(model2.get(sort.key)) === "undefined" ? model2._extra[sort.key] : model2.get(sort.key);
				switch(sort.datatype){
					case "string":
						if (sortFunction(value1,model1)===sortFunction(value2,model2))
							return 0;
						return self.sortInfo.direction*(sortFunction(value1,model1)<sortFunction(value2,model2)? -1: 1);
						break;
					case "integer":
						if(parseInt(sortFunction(value1,model1))===parseInt(sortFunction(value2,model2))){return 0;}
					    return self.sortInfo.direction*(parseInt(sortFunction(value1,model1))<parseInt(sortFunction(value2,model2))? -1:1);
						break;
					case "boolean":
						if(sortFunction(value1,model1)===sortFunction(value2,model2)){ return 0;}
						return self.sortInfo.direction*(sortFunction(value1,model1)<sortFunction(value2,model2)?-1:1);
						break;
					case "number":
						if(parseFloat(sortFunction(value1,model1))===parseFloat(sortFunction(value2,model2))){return 0;}
					    return self.sortInfo.direction*(parseFloat(sortFunction(value1,model1))<parseFloat(sortFunction(value2,model2))? -1:1);
						break;
				} 

			};



			/* Need a more robust comparator function. */
			/*this.collection.comparator = function(model1,model2) { 
				switch(sort.datatype){
					case "string":
						if (sortFunction(model1.get(sort.sort_key))===sortFunction(model2.get(sort.sort_key))) {return 0;}
						return self.sortInfo.direction*
							(sortFunction(model1.get(sort.sort_key))<sortFunction(model2.get(sort.sort_key))? -1: 1);
					break;
					case "integer":
						if(parseInt(sortFunction(model1.get(sort.sort_key)))===parseInt(sortFunction(model2.get(sort.sort_key)))){return 0;}
					    return self.sortInfo.direction* 
					    	(parseInt(sortFunction(model1.get(sort.sort_key)))<parseInt(sortFunction(model2.get(sort.sort_key)))? -1:1);

					break;
				} 
				
			}; */
			this.collection.sort();
			this.render();
		},
		firstPage: function() { this.gotoPage(0);},
		prevPage: function() {if(this.currentPage>0) {this.gotoPage(this.currentPage-1);}},
		nextPage: function() {
			if(this.currentPage<this.maxPages){this.gotoPage(this.currentPage+1);}
		},
		lastPage: function() {this.gotoPage(this.maxPages-1);},
		gotoPage: function(arg){
			this.currentPage = /^\d+$/.test(arg) ? parseInt(arg,10) : parseInt($(arg.target).text(),10)-1;
			this.pageRange = _.range(this.currentPage*this.pageSize,
				(this.currentPage+1)*this.pageSize>this.collection.size()? this.collection.size():(this.currentPage+1)*this.pageSize);
			this.render();
			if(this.currentPage==0){
				this.$("button.first-page,button.prev-page").attr("disabled","disabled");
			} else {
				this.$("button.first-page,button.prev-page").removeAttr("disabled");
			}
			if(this.currentPage==this.maxPages-1){
				this.$("button.last-page,button.next-page").attr("disabled","disabled");
			} else {
				this.$("button.last-page,button.next-page").removeAttr("disabled");
			}
		},
		pageChanged: function(){
			this.trigger("page-changed",this.currentPage);
		},
		setPageNumber: function(num){
			this.gotoPage(num);
		}



	});

	var TableRowView = Backbone.View.extend({
		tagName: "tr",
		initialize: function (options) {
			_.bindAll(this,"render");
			this.bindings = options.bindings;
			this.columnInfo = options.columnInfo;
		},
		render: function () {
			var self = this;
			_(this.columnInfo).each(function (col){
				var classname = _.isArray(col.classname) ? col.classname.join(" ") : col.classname;
				if (col.datatype === "boolean"){
					var select = $("<select>").addClass(classname).addClass("input-small");
					self.$el.append($("<td>").append(select));
				} else if(col.use_contenteditable){
					self.$el.append($("<td>").addClass(classname).attr("contenteditable",col.editable));
				} else {
					if (col.stickit_options && col.stickit_options.selectOptions){
						var select = $("<select>").addClass("input-small").addClass(classname);
						self.$el.append($("<td>").append(select));
					} else {
						self.$el.append($("<td>").addClass(classname));
					}
				}
			});
			if(this.model){
				this.stickit();
			}
			return this; 
		}, 
		setModel: function(_model){
			if(typeof(_model)=="undefined"){
				this.$el.html("");
			} else {
				if(this.$el.html().length==0){
					this.render();
				}
				this.model=_model;
				this.stickit();
			}
		},
		refresh: function(){
			this.stickit();
		},
		events: {
			"keypress td[contenteditable='true']": "returnHit"
		},
		returnHit: function(evt){
			if (evt.keyCode==13){
				$(evt.target).blur();
			}
		}

	});

	return CollectionTableView;

});