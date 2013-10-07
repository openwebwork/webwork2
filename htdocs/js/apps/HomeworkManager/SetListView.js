/**
 *  This view has a listing of all the HW sets (similar to the old Homework Editor)
 *
 */

define(['Backbone', 'underscore','views/EditGrid','config','views/ModalView','models/ProblemSet'], 
    function(Backbone, _,EditGrid,config,ModalView,ProblemSet){

    
    var SetListView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this, 'render','customizeGrid','gridChanged','updateGrid');  // include all functions that need the this object
            var self = this;
            this.problemSets = this.options.problemSets;
            this.users = this.options.users;

            this.editgrid = new EditGrid({el: $("#allSets"), grid_name: "problem-set-grid", table_name: "sets-table-container",
                    paginator_name: "#sets-table-paginator", template_name: "#all-problem-sets-template",
                    enableSort: true, pageSize: 10,collection: this.problemSets,
                    bindings: {".open_date" : "open_date"}});
            
            this.editgrid.grid.load({metadata: config.problemSetHeaders});
            this.customizeGrid();
            this.editgrid.grid.modelChanged = this.gridChanged;
            this.problemSets.on("change",this.updateGrid);
            this.problemSets.on("add",this.updateGrid);
            this.problemSets.on("remove",this.updateGrid);
            console.log("in SetListView");

            this.headerInfo = { template: "#allSets-header", 
                events: {"click .add-problem-set-button": function () {
                                  self.addProblemSet();  
                                }}
            };

        },
        events: {"click .add-problem-set-button": "addProblemSet"},
        updateGrid: function (){
            var self = this; 
            var _data = this.problemSets.map(function(_set) { 
                var _values = _set.attributes;
                _.extend(_values,{num_problems: _set.get("problems").size(), 
                    users_assigned: _set.get("assigned_users").length + "/" + self.users.size()});

                return {id: _set.cid, values: _values};});
            this.editgrid.grid.load({data: _data});
            this.editgrid.updateGrid();
            this.editgrid.updatePaginator();
        },
        gridChanged: function(rowIndex, columnIndex, oldValue, newValue) {
            if(columnIndex==0){
                this.deleteProblemSet(this.problemSets.get(this.editgrid.grid.getRowId(rowIndex)),rowIndex);
                return;
            }

            if (this.editgrid.grid.getColumnName(columnIndex).match(/date/)) { 
                var oldDate = moment.unix(oldValue)
                    , newDate = moment.unix(newValue);

                // check if the day has actually changed. 
                if (! oldDate.isSame(newDate,"day")){
                    newDate.hours(oldDate.hours()).minutes(oldDate.minutes());
                    this.problemSets.get(this.editgrid.grid.getRowId(rowIndex))
                        .set(this.editgrid.grid.getColumnName(columnIndex),newDate.unix()).update();
                } 
            } else {
                this.problemSets.get(this.editgrid.grid.getRowId(rowIndex))
                    .set(this.editgrid.grid.getColumnName(columnIndex),newValue).save();
            }
            this.editgrid.grid.refreshGrid();
        },
        render: function () {
            var self = this;
            this.editgrid.render();

            this.updateGrid();
        },
        deleteProblemSet: function (set,row){
            var del = confirm("Are you sure you want to delete the set " + set.get("set_id") + "?");
            if(del){
                this.editgrid.grid.remove(row);
                set.collection.remove(set);
            }
        },
        addProblemSet: function (){
            if (! this.addProblemSetView){
                (this.addProblemSetView = new AddProblemSetView({problemSets: this.problemSets})).render();
            } else {
                this.addProblemSetView.setModel(new ProblemSet()).render().open();
            }
        },

        /**
        *  pstaab: perhaps put a lot of this code in the config.js file
        *
        */

        customizeGrid: function () {
            var dateRenderer = new CellRenderer({
                render: function(cell, value) { 
                    $(cell).html(moment.unix(value).format("MM/DD/YYYY")); 
                }
            });
            this.editgrid.grid.setCellRenderer("open_date", dateRenderer);
            this.editgrid.grid.setCellRenderer("due_date", dateRenderer);
            this.editgrid.grid.setCellRenderer("answer_date", dateRenderer);

            this.editgrid.grid.setCellRenderer("delete_set",config.deleteCellRenderer,{action: "delete"});

            
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

                $(htmlInput).datepicker({dateFormat: "mm/dd/yy",
                            beforeShow: function() {
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
                    }).datepicker("setDate","07/25/2012").datepicker("show");

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

    var AddProblemSetView = ModalView.extend({
        initialize: function () {
            _.bindAll(this,"render","addNewSet");
            this.model = new ProblemSet();


            _.extend(this.options, {template: $("#add-hw-set-template").html(), 
                templateOptions: {name: config.courseSettings.user},
                buttons: {text: "Add New Set", click: this.addNewSet}});
            this.constructor.__super__.initialize.apply(this); 

            this.problemSets = this.options.problemSets; 

              /*  Not sure why the following doesn't pass the options along. 
              this.constructor.__super__.initialize.apply(this,
                {template: $("#modal-template").html(), templateOptions: {header: "<h3>Create a New Problem Set</h3>", 
                                saveButton: "Create New Set"}, modalBodyTemplate: $("#add-hw-set-template").html(),
                                modalBodyTemplateOptions: {name: config.requestObject.user}});  */
        },
        render: function () {
            this.constructor.__super__.render.apply(this); 

            return this;
        },
        setModel: function(_model){
            this.model = _model;
            return this;
        },
        bindings: {".problem-set-name": "set_id"},
        events: {"keyup .problem-set-name": "validateName"},
        validateName: function(ev){
            // this.model.preValidate("set_id"),$(ev.target).val())
            var errorMsg = this.model.preValidate("set_id",$(ev.target).val());
            if(errorMsg){
                this.$(".problem-set-name").css("background","rgba(255,0,0,0.5)");
                this.$(".problem-set-name-error").html(errorMsg);
            } else {
                this.$(".problem-set-name").css("background","none");
                this.$(".problem-set-name-error").html("");
            }
        },
        addNewSet: function() {
            // need to validate here. 
            /*
            var errorMessage = this.model.preValidate('set_id', setname);
            if (errorMessage){
                this.$("#new-set-modal .modal-body").append("<div style='color:red'>The name of the set must contain only letters numbers, '.', _ and no spaces are allowed.");
                return;
            }  */
 
            this.model.setDefaultDates(moment().add(10,"days")).set("assigned_users",[config.courseSettings.user]);
            console.log(this.model.attributes);
            console.log("adding new set");
            this.problemSets.add(this.model);
            this.close();
        }

    });
    return SetListView;

});