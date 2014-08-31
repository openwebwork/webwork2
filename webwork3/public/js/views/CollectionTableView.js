/**
 * 
 *  A backbone view replacement for editable grid
 *
 *  A collection must be passed into the constructor. Also with an array of Column names. 
 * The following must also be passed into the View:
 *  
 * columnInfo:  An array of {name: _name, key: _key, editable: boolean, classnames: _classnames,
 		datatype: _datatype, searchable: _searchable, binding: _binding} where 
 	-  _name will be the header of the column
 	-  _key is the field name of the model 
 	-  _editable is a boolean for whether or not the column is editable
 	-  _classnames will assign the td element in the table those classnames.  It can be either a string or an
 			array of strings.
 	-  _datatype will be the type of data for the column.  This is important for sorting.
 	-  _searchable (a boolean) whether or not the value should be available in search/filter
 	-  _search_function (function) to be used to set the value of the searchable field instead of the field itself. 
 	-  _use_contenteditable: boolean  (this uses the contenteditable attribute whenever a column is editable. Set to 
 	         false if you don't want to use this or true or nothing to use it.)
 	-  _stickit_options: is an stickit bindings object.  You don't need to define observe because the classname will 
 	        be passed in.
 	-  _sortFxn: is a function that returns a value to be sorted on.   

Required options:
	- row_id_field: the field from the collections model that acts like an id.  

Other options:
	page_size: the number of rows in a visible table (or -1 for all rows shown.)
	table_classes: a string consisting of all classes to be set on the table.  


Sorting: 
   The table will sort unless the datatype field is not set.  It will sort both ascending and descending. 
   Currently only "integer" and "string" data is set, however boolean data sorts as expected as well. 
   If you want to sort on a different piece of data, you need to specify the key (field) where the data is stored. 
 */


define(['backbone', 'underscore','config','stickit'], function(Backbone, _,config){

	var CollectionTableView = Backbone.View.extend({
		tagName: "table",
		initialize: function (options) {
			var self = this;
			_.bindAll(this,"render","sortTable");
			this.original_collection = this.collection; 
			this.collection = new Backbone.Collection();
			_(this).extend(_(options).pick("columnInfo","row_id_field","page_size","table_classes"))
			this.filteredCollection = new Backbone.Collection();
			this.filter_string = "";
			this.selectedRows = [];  // keep track of the rows that are selected. 
			this.paginatorProp = options.paginator;
			this.setColumns(options.columnInfo);
			if($(options.tablename).length>0){ // if the tablename was passed use it as the $el
				this.$el=$(options.tablename);
			}
			if(typeof(this.row_id_field)==="undefined"){
				console.error("The option row_id_field must be passed to the table");
			}
			if(typeof(options.paginator.showPaginator)==="undefined"){
				this.paginatorProp.showPaginator = true;	
			}
			this.initializeTable();
		},
		initializeTable: function () {
			var self = this;
			this.original_collection.each(function(_model){
				self.updateRow(_model);
			});

			// this connects the collection in the table to the original collection so changes can be made automatically. 
			this.collection.on({
				change: function(model){
					var id = model.get(self.row_id_field);
					var original_model = self.original_collection.find(function(_m){ return _m.get(self.row_id_field)===id});
					original_model.set(model.changed);
				},
				remove: function(model){
					var id = model.get(self.row_id_field);
					var original_model = self.original_collection.find(function(_m){ return _m.get(self.row_id_field)===id});
					self.original_collection.remove(original_model);
				}
			});

			this.original_collection.on({
				change: function(model){
					var id = model.get(self.row_id_field);
					var _model = self.collection.find(function(_m){ return _m.get(self.row_id_field)===id});
					_model.set(model.changed);
				},
				add: function(model){
					self.updateRow(model);
				},
				remove: function(model){
					var id = model.get(self.row_id_field);
					var _model = self.collection.find(function(_m){ return _m.get(self.row_id_field)===id});
					self.collection.remove(_model);
					self.filteredCollection.remove(_model);
				}
			});

			this.pageRange = this.page_size > 0 ?  _.range(this.page_size) : _.range(this.original_collection.length) ;
			this.currentPage = 0;
			this.rowViews = [];


			this.sortInfo = {};  //stores the sort column and sort direction
		},
		updateRow: function(_model){
			var model = new Backbone.Model();
			_(this.columnInfo).each(function(col){
				var value;
				if(_.isFunction(col.value)){
					value = col.value(_model);
				} else if(_model.get(col.key)){
					value = _model.get(col.key)
				}
				if(col.searchable){
					var v = _.isFunction(col.search_value) ? col.search_value(_model) : value; 
					if(typeof(v)!=="undefined"){
						model.set("_searchable_fields",
							typeof(model.get("_searchable_fields"))==="undefined"? v : 
							model.get("_searchable_fields")+";" + v); 	
					}
				}
				switch(col.datatype){
					case "integer": 
						model.set(col.key,parseInt(value));
						break;
					case "string": 
						model.set(col.key,(typeof(value)==="undefined") ? "" : ""+value);
						break;
					case "boolean":
					default: 
						model.set(col.key,typeof(value)==="undefined" ? "" : value);
				}
			})
			this.collection.add(model);
			this.trigger("table-changed");
		},
		setColumns: function(){
			var self = this;
			this.bindings = {};
			_(this.columnInfo).each(function(col){ 
				var obj = {};
				var classname = / +/.test(col.classname) ? col.classname.split(/ +/)[0] : col.classname;
				obj["."+classname] = {observe: col.key}; // set it up for stickit format
				
				if(typeof col.use_contenteditable == 'undefined'){ col.use_contenteditable=false;}
				if(typeof col.stickit_options != 'undefined'){
					_.extend(obj["."+classname],col.stickit_options);
					col.use_contenteditable = col.editable;
				}
				self.collection.each(function(_model){
					self.updateValues(_model,col);
				});
				if(typeof(col.datatype)!=="undefined"){
					col.sortable = true;
				}
				if(typeof(col.searchable)==="undefined"){
					col.searchable = true;
				}
				if(col.key==="_select_row"){
					col.searchable = false; 
				}
				if(typeof(col.show_column)==="undefined"){
					col.show_column = true;
				}
				_.extend(self.bindings, obj);
			});
			return this;
		},
		render: function () {
			var self = this, i;
			this.$el.empty().append($("<thead>")).append($("<tbody>"));
			this.updateHeader();
			this.updateTable();
			this.$el.addClass("sortable-table").addClass(this.table_classes);
			return this;
		},
		updateHeader: function () {
			var self = this;
						// set up the HTML for the table header
			var headRow = $("<tr>");

			_(this.columnInfo).each(function (col){
				if(col.key==="_select_row"){
					col.colHeader = "<input type='checkbox' class='_select_row' data-key-name='"+col.key+"'>";
				}
				
				var spanIcon = ""; 
				if(self.sortInfo && ! _.isEqual(self.sortInfo,{}) && self.sortInfo.key == col.key){
					var type = _(self.columnInfo).findWhere({key: col.key}).datatype;
					var iconClass = config.sortIcons[type+self.sortInfo.direction];
					spanIcon = "<i class='fa " + iconClass + "'></i>";
				}
				var th = $("<th data-key-name='" + col.key + "'>").addClass(col.classname)
					.html(col.colHeader? col.colHeader: col.name + spanIcon);
				if(col.title){
					th.attr("title",col.title);
				}
				if(col.show_column){
					headRow.append(th);	
				}
			});
			this.$("thead").html(headRow);
		},
		updateTable: function () {
			var self = this;
			this.rowViews = [];
			_(this.pageRange).each(function(i,j){
				if(self.filter_string.length>0){ 
					if(self.filteredCollection.at(i)){
						self.rowViews[j] = new TableRowView({model: self.filteredCollection.at(i),columnInfo: self.columnInfo,
							bindings: self.bindings,rowID: self.filteredCollection.at(i).get(self.row_id_field)});
					}
				} else {
					if(self.collection.at(i)){
						self.rowViews[j]=new TableRowView({model: self.collection.at(i),columnInfo: self.columnInfo, 
							bindings: self.bindings,rowID: self.collection.at(i).get(self.row_id_field)});
					}
				}
			});
			var tbody = this.$("tbody").empty();
			if(this.page_size >0){
				for(i=0;i<this.page_size;i++){
					if(this.rowViews[i]){
						tbody.append(self.rowViews[i].render().el);
					}
				}
			} else {
				_(this.rowViews).each(function(row){
					tbody.append(row.render().el);
				});
			}
			_(this.selectedRows).each(function(rowID){
				self.$("tr[data-row-id='"+rowID+"'] ._select_row").prop("checked",true);
			})

			if(this.paginatorProp.showPaginator){
				tbody.append($("<tr class='paginator-row'>"));
				this.updatePaginator();
			}
			this.delegateEvents(); // why is this needed?
			this.trigger("table-changed");
			return this;
		},
		refreshTable: function (){
			_(this.rowViews).each(function(row){row.refresh();});
			return this;
		},
		updatePaginator: function() {   // render the paginator
			if (this.filter_string.length>0){
				this.maxPages = Math.ceil(this.filteredCollection.length/this.page_size);
			} else {
				this.maxPages = Math.ceil(this.collection.length / this.page_size);
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

			return this;
		},
		// this is the workhorse for changing the table.  Call set with an object of properties/values
		set: function(options){
			var self = this;
			if(options.page_size){
				this.page_size = options.page_size;
				this.currentPage = 0;
				this.paginatorProp.showPaginator = this.page_size > 0; 
			}
			if(options.sort_info){
				this.sortTable(options.sort_info);
			}
			if(options.selected_rows){
				this.selectedRows = options.selected_rows;
			}
			if(typeof(options.filter_string)!=="undefined"){
				if(this.currentPage != 0){
					this.gotoPage(0);
				}
				this.filter_string = options.filter_string;
		        var containsColon = /^\s*(.*):(.*)\s*$/.exec(this.filter_string)  // filter on a specific field
		        	, filterRE; 
				if(containsColon){
		            containsColon.shift();  // remove the first element of the array
		            this.filteredCollection.reset(this.collection.where(_.object([containsColon])));
		        } else if (this.filter_string.length>0) {
					filterRE = new RegExp(this.filter_string,"i");
					this.filteredCollection.reset(this.collection.filter(function(model){
						return model.get("_searchable_fields").search(filterRE) > -1;
					}));
				}
			}
			if(typeof(options.current_page)!=="undefined"){
				this.currentPage = options.current_page;
			
			}
			if(this.page_size>0){
				if(this.currentPage*this.page_size>this.collection.length){
					this.currentPage = 0; 
				}
				this.pageRange = _.range(this.currentPage*this.page_size,
					(this.currentPage+1)*this.page_size>this.collection.size()? this.collection.size():(this.currentPage+1)*this.page_size);
			} else {
				this.pageRange = _.range(0,this.collection.length);
			}

			return this;
		},
		getRowCount: function () {
			return this.rowViews.length;
			//return (this.filter_string.length>0)? this.filteredCollection.length : this.collection.length;
		},
		events: {
			"click th": "headerClicked",
			"click .first-page": "firstPage",
			"click .prev-page": "prevPage",
			"click .numbered-page": "gotoPage",
			"click .next-page": "nextPage",
			"click .last-page": "lastPage",
			"click button.paginator-page": "pageChanged",
			"change input._select_row": "selectRow"
		},
		headerClicked: function (evt) {
			var target = $(evt.target).is("i") ? $(evt.target).parent() : $(evt.target); 
			if(_(this.columnInfo).findWhere({key: target.data("key-name")}).sortable){
				this.sortTable(evt).render();
				this.trigger("table-sorted",this.sortInfo);				
			} else if ($(evt.target).hasClass("_select_row")){
				this.$("input._select_row[type='checkbox']").prop("checked",$(evt.target).prop("checked"));
				this.selectedRows = $.makeArray(this.$("tr[data-row-id]:has(input._select_row:checked)")
					.map(function(i,v){ return $(v).data("row-id");}));
				this.trigger("selected-row-changed",this.selectedRows);	
			}
		},
		selectRow: function (evt){
			var rowID = $(evt.target).closest("tr").data("row-id");
			if($(evt.target).prop("checked")){
				this.selectedRows.push(rowID);
			} else {
				this.selectedRows = _(this.selectedRows).without(rowID);
			}
			this.trigger("selected-row-changed",this.selectedRows);
		},
		getVisibleSelectedRows: function (){ // returns only the selected rows on the current page. 
			var self = this;
			var visibleRows = $.makeArray(this.$("tr").map(function(i,v){ return self.$(v).data("row-id");}));
			return _.intersection(visibleRows, this.selectedRows);
		},
		sortTable: function(evt){
			var self = this
				, sort 
				, sortKey = evt.sort_key || $(evt.target).data("key-name") || $(evt.target).parent().data("key-name");

			if(typeof(sortKey)==="undefined"){
				return this;
			}

			sort = _(this.columnInfo).findWhere({key: sortKey});
			if(typeof(sort)=="undefined" || !sort.sortable){ // The user clicked on the select all button.
				return this;
			}


			if(evt.sort_direction && evt.sort_key){
				this.sortInfo = {key: sort.key, direction: evt.sort_direction};
			}	else {
				if(this.sortInfo && this.sortInfo.key==sort.key){
					this.sortInfo.direction = -1*this.sortInfo.direction;
				} else {
					this.sortInfo = {key: sort.key, direction: 1};
				}
			}

			if(typeof(sort.datatype)==="undefined"){
				console.error("You need to define a datatype to sort");
				return this;
			}

			var comp = _.isFunction(sort.search_value) ? sort.search_value : sort.key;

			if(this.filter_string.length>0){
				this.filteredCollection.comparator = comp;
				this.filteredCollection.sort();
				if(self.sortInfo.direction<0){
					this.filteredCollection.models = this.filteredCollection.models.reverse();
				}
	
			} else {
				//this.collection.comparator = comparator;
				this.collection.comparator = comp;
				this.collection.sort();	
				if(self.sortInfo.direction<0){
					this.collection.models = this.collection.models.reverse();
				}
			}
			this.updateHeader();
			return this;
		},
		firstPage: function() { this.gotoPage(0);},
		prevPage: function() {if(this.currentPage>0) {this.gotoPage(this.currentPage-1);}},
		nextPage: function() {
			if(this.currentPage<this.maxPages){this.gotoPage(this.currentPage+1);}
		},
		lastPage: function() {this.gotoPage(this.maxPages-1);},
		gotoPage: function(arg){
			this.set({current_page: /^\d+$/.test(arg) ? parseInt(arg,10) : parseInt($(arg.target).text(),10)-1});
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
			this.updateTable();
			return this;
		},
		pageChanged: function(){
			this.trigger("page-changed",this.currentPage);
		}
	});

	var TableRowView = Backbone.View.extend({
		tagName: "tr",
		initialize: function (options) {
			var self = this;
			_.bindAll(this,"render");
			this.bindings = options.bindings;
			this.columnInfo = options.columnInfo;
			this.rowID = options.rowID;
			this.model.on("remove",function(model){
				self.remove();
			});
		},
		render: function () {
			var self = this;
			this.$el.attr("data-row-id",this.rowID);
			_(this.columnInfo).each(function (col){
				if(!col.show_column){

				} else if (col.datatype === "boolean"){
					var checkbox = $("<input type='checkbox'>").addClass(col.classname);
					self.$el.append($("<td align='center'>").append(checkbox));
				} else if(col.key==="_select_row"){
					var cb = $("<input type='checkbox' class='_select_row'>");
					self.$el.append($("<td>").append(cb));
				} else if(col.use_contenteditable){
					self.$el.append($("<td>").addClass(col.classname).attr("contenteditable",col.editable));
				} else if(col.display) {
					self.$el.append($("<td>").text(col.display(self.model.get(col.key))));
				} else if (col.stickit_options && col.stickit_options.selectOptions){
					var select = $("<select>").addClass("input-sm form-control").addClass(col.classname);
					self.$el.append($("<td>").append(select));
				} else {
					self.$el.append($("<td>").addClass(col.classname));
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