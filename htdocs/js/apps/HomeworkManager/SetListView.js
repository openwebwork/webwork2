/**
 *  This view has a listing of all the HW sets (similar to the old Homework Editor)
 *
 */

define(['Backbone', 'underscore','views/CollectionTableView','config','views/ModalView','models/ProblemSet'], 
    function(Backbone, _,CollectionTableView,config,ModalView,ProblemSet){

    
    var SetListView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this, 'render','addProblemSet');  // include all functions that need the this object
            var self = this;
            this.problemSets = this.options.problemSets;
            this.users = this.options.users;

            this.tableSetup();

            this.headerInfo = { template: "#allSets-header", 
                events: {"click .add-problem-set-button": function () {
                                  self.addProblemSet();  
                                }}
            };

            this.problemSets.on("change",function (model) {
                model.save();
            })

        },
        //events: {"click .add-problem-set-button": "addProblemSet"},
        render: function () {
            this.userTable = new CollectionTableView({columnInfo: this.cols, collection: this.problemSets, 
                                paginator: {page_size: 10, button_class: "btn", row_class: "btn-group"}});
            this.userTable.render().$el.addClass("table table-bordered table-condensed");
            this.$el.html(this.userTable.el);

            // set up some styling
            this.userTable.$(".paginator-row td").css("text-align","center");
            this.userTable.$(".paginator-page").addClass("btn");
        },
        deleteProblemSet: function (set,row){
            var del = confirm("Are you sure you want to delete the set " + set.get("set_id") + "?");
            if(del){
            //    this.editgrid.grid.remove(row);
            //    set.collection.remove(set);
            }
        },
        addProblemSet: function (){
            if (! this.addProblemSetView){
                (this.addProblemSetView = new AddProblemSetView({problemSets: this.problemSets})).render();
            } else {
                this.addProblemSetView.setModel(new ProblemSet()).render().open();
            }
        },

        tableSetup: function () {
            var self = this;
            this.cols = [{name: "Set Name", key: "set_id", classname: "set-id", editable: false, datatype: "string"},
            {name: "Users Assign.", key: "assigned_users", classname: "users-assigned", editable: false, datatype: "integer",
                stickit_options: {onGet: function(val){
                    return val.length + "/" + self.problemSets.length;
                }},
                sort_function: function(val){ return val.length;}
                },
            {name: "Num. of Probs.", key: "problems", classname: "num-problems", editable: false, datatype: "integer",
                stickit_options: {onGet: function(val){return val.length;  }},
                sort_function: function(val){
                    return val.length;
                }    
            },
            {name: "Reduced Scoring", key: "enable_reduced_scoring", classname: "enable-reduced-scoring", editable: true, 
                    datatype: "string", stickit_options: { selectOptions: { collection: [{value: 0, label: "No"},{value: 1, label: "Yes"}]}}},
            {name: "Visible", key: "visible", classname: "is-visible", editable: true, datatype: "string",
                    stickit_options: { selectOptions: { collection: [{value: 0, label: "No"},{value: 1, label: "Yes"}]}}},
            {name: "Open Date", key: "open_date", classname: ["open-date","edit-datetime"], 
                    editable: false, datatype: "integer", use_contenteditable: false},
            {name: "Due Date", key: "due_date", classname: ["due-date","edit-datetime"], 
                    editable: false, datatype: "integer", use_contenteditable: false},
            {name: "Answer Date", key: "answer_date", classname: ["answer-date","edit-datetime"], 
                    editable: false, datatype: "integer", use_contenteditable: false}
            ];

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