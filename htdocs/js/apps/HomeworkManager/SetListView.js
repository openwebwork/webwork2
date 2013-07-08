/**
 *  This view has a listing of all the HW sets (similar to the old Homework Editor)
 *
 */

define(['Backbone', 'underscore','editablegrid','config'], 
    function(Backbone, _,EditableGrid,config){

    
    var SetListView = Backbone.View.extend({
        className: "set-list-view",
        initialize: function () {
            _.bindAll(this, 'render','customizeGrid','gridChanged');  // include all functions that need the this object
          
            this.problemSets = this.options.problemSets;
            this.grid = new EditableGrid("problem-set-grid",{ enableSort: true,pageSize: 10});
            var _data = this.problemSets.map(function(_set) { return {id: _set.cid, values: _set.attributes};});
            this.grid.load({metadata: config.problemSetHeaders, data: _data});
            this.customizeGrid();
            this.grid.modelChanged = this.gridChanged;
          
        },
        gridChanged: function(rowIndex, columnIndex, oldValue, newValue) {

            if ([3,4,5].indexOf(columnIndex)>-1) {  // it's a date
                var oldDate = moment.unix(oldDate)
                    , newDate = moment.unix(newDate);
            }
        },
        render: function () {
            var self = this;
            this.$el.html($("#all-problem-sets-template").html());
          
            this.grid.renderGrid("sets-table-container","table table-bordered table-condensed","users-table");
            this.grid.setPageIndex(0);
        },
        customizeGrid: function () {
            var dateRenderer = new CellRenderer({
                render: function(cell, value) { 
                    $(cell).html("<span class='date'>" + moment.unix(value).format("MM/DD/YYYY") + "</span>" + 
                                    "<i class='icon-time' style='margin-left:1ex;'></i>"); }
            });
            this.grid.setCellRenderer("open_date", dateRenderer);
            this.grid.setCellRenderer("due_date", dateRenderer);
            this.grid.setCellRenderer("answer_date", dateRenderer);

            
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

            this.grid.setCellEditor("open_date", new DateEditor({col: "open_date"}));
            this.grid.clearCellValidators("open_date");
            this.grid.setCellEditor("due_date", new DateEditor({col: "due_date"}));
            this.grid.clearCellValidators("due_date");
            this.grid.setCellEditor("answer_date", new DateEditor({col: "answer_date"}));
            this.grid.clearCellValidators("answer_date");

        }


    });
    return SetListView;

});