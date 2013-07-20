/**
 *  This view has a listing of all the HW sets (similar to the old Homework Editor)
 *
 */

define(['Backbone', 'underscore','../../lib/views/EditGrid','config'], 
    function(Backbone, _,EditGrid,config){

    
    var SetListView = Backbone.View.extend({
        className: "set-list-view",
        initialize: function () {
            _.bindAll(this, 'render','customizeGrid','gridChanged','updateGrid');  // include all functions that need the this object
          
            this.problemSets = this.options.problemSets;

            this.editgrid = new EditGrid({el: $("#allSets"), grid_name: "problem-set-grid", table_name: "sets-table-container",
                    paginator_name: "#sets-table-paginator", template_name: "#all-problem-sets-template",
                    enableSort: true, pageSize: 10});
            
            this.editgrid.grid.load({metadata: config.problemSetHeaders});
            this.customizeGrid();
            this.editgrid.grid.modelChanged = this.gridChanged;
            this.problemSets.on("change",this.updateGrid);
            this.problemSets.on("add",this.updateGrid);
            this.problemSets.on("remove",this.updateGrid);
            this.render();
            console.log("in SetListView");

        },
        updateGrid: function (){
            var _data = this.problemSets.map(function(_set) { return {id: _set.cid, values: _set.attributes};});
            this.editgrid.grid.load({data: _data});
            this.editgrid.grid.refreshGrid();
            this.editgrid.updatePaginator();
        },
        gridChanged: function(rowIndex, columnIndex, oldValue, newValue) {

            if ([3,4,5].indexOf(columnIndex)>-1) {  // it's a date
                var oldDate = moment.unix(oldValue)
                    , newDate = moment.unix(newValue);

                // check if the day has actually changed. 
                if (! oldDate.isSame(newDate,"day")){
                    newDate.hours(oldDate.hours()).minutes(oldDate.minutes());
                    this.problemSets.get(this.editgrid.grid.getRowId(rowIndex)).set(this.grid.getColumnName(columnIndex),newDate.unix()).update();
                } 
            } else {
                this.problemSets.get(this.editgrid.grid.getRowId(rowIndex)).set(this.grid.getColumnName(columnIndex),newValue).update();
            }
            this.editgrid.grid.refreshGrid();
        },
        render: function () {
            var self = this;
            this.editgrid.render();
            this.updateGrid();
        },
        customizeGrid: function () {
            var dateRenderer = new CellRenderer({
                render: function(cell, value) { 
                    $(cell).html("<span class='date'>" + moment.unix(value).format("MM/DD/YYYY") + "</span>" + 
                                    "<i class='icon-time' style='margin-left:1ex;'></i>"); }
            });
            this.editgrid.grid.setCellRenderer("open_date", dateRenderer);
            this.editgrid.grid.setCellRenderer("due_date", dateRenderer);
            this.editgrid.grid.setCellRenderer("answer_date", dateRenderer);

            
            function DateEditor(config) 
            {
                // erase defaults with given options
                this.init(config); 
            };

            // redefine displayEditor to setup datepicker
            DateEditor.prototype = new TextCellEditor();
            DateEditor.prototype.displayEditor = function(element, htmlInput) 
            {
                // call base method
                TextCellEditor.prototype.displayEditor.call(this, element, htmlInput);

                // determine the open, due and answer dates
                var openDate = moment($(element).parent().children("td:nth-child(4)").text(),"MM/DD/YYYY")
                    , dueDate = moment($(element).parent().children("td:nth-child(5)").text(),"MM/DD/YYYY")
                    , answerDate = moment($(element).parent().children("td:nth-child(6)").text(),"MM/DD/YYYY")
                    , _maxDate = ""
                    , _minDate = "";
                
                // change the date from unix seconds to standard format
                console.log("in displayEditor");

                switch(this.col){
                    case "open_date": _maxDate = dueDate.toDate();
                    break;
                    case "due_date": _minDate = openDate.toDate(), _maxDate = answerDate.toDate();
                    break;
                    case "answer_date": _minDate = dueDate.toDate();
                    break;
                }

                $(htmlInput).val(moment.unix($(htmlInput).val()).format("MM/DD/YYYY"))
                    .datepicker({beforeShow: function() {
                            // the field cannot be blurred until the datepicker has gone away
                            // otherwise we get the "missing instance data" exception
                            this.onblur_backup = this.onblur;
                            this.onblur = null;
                        }, maxDate: _maxDate, minDate: _minDate,
                        onClose: function(dateText) {
                            console.log(dateText);
                            // apply date if any, otherwise call original onblur event
                            if (dateText != '') this.celleditor.applyEditing(htmlInput.element, moment(dateText,"MM/DD/YYYY").unix());
                            else if (this.onblur_backup != null) this.onblur_backup();

                        }
                    }).datepicker("show");

                $(".ui-datepicker").position({my: "right", at: "left", of: $(htmlInput), collision: "flipfit", 
                                                within: $("#main-view")});
                
            }

            this.editgrid.grid.setCellEditor("open_date", new DateEditor({col: "open_date"}));
            this.editgrid.grid.clearCellValidators("open_date");
            this.editgrid.grid.setCellEditor("due_date", new DateEditor({col: "due_date"}));
            this.editgrid.grid.clearCellValidators("due_date");
            this.editgrid.grid.setCellEditor("answer_date", new DateEditor({col: "answer_date"}));
            this.editgrid.grid.clearCellValidators("answer_date");

        }


    });
    return SetListView;

});