/**
 *  This view has a listing of all the HW sets (similar to the old Homework Editor)
 *
 */

define(['backbone', 'underscore','views/MainView', 'views/CollectionTableView','config','apps/util',
    'views/ModalView','models/ProblemSet','models/AssignmentDate',
    'jquery-truncate'], 
    function(Backbone, _,MainView,CollectionTableView,config,util,ModalView,ProblemSet,AssignmentDate){

    
    var ProblemSetsManager = MainView.extend({
        initialize: function (options) {
            MainView.prototype.initialize.call(this,options);
            _.bindAll(this, 'render','addProblemSet','updateTable','filterProblemSets','clearFilterText',
                        'hideShowReducedScoring');  // include all functions that need the this object
            var self = this;
            this.problemSets = options.problemSets;
            this.users = options.users;

            this.tableSetup();

            this.headerInfo = { template: "#allSets-header", 
                events: {"click .add-problem-set-button": function () {
                                  self.addProblemSet();  
                                }}
            };
            this.problemSets.on("add",this.updateTable);
            this.problemSets.on("remove",this.updateTable);
            this.problemSets.on("change:enable_reduced_scoring",this.hideShowReducedScoring);
            this.setMessages();
        },
        events: {
            "click .add-problem-set-button": "addProblemSet",
            'keyup input.filter-text' : 'filterProblemSets',
            'click button.clear-filter-button': 'clearFilterText',
            //'change .enable-reduced-scoring': "hideShowReducedScoring"
        },
        hideShowReducedScoring: function(model){
            if(model.get("enable_reduced_scoring")==1 && model.get("reduced_scoring_date")===""){
                var rcDate = moment.unix(model.get("due_date")).subtract(this.settings.getSettingValue("pg{ansEvalDefaults}{reducedScoringPeriod}"))
                model.set({reduced_scoring_date: rcDate.unix()})
            }
            this.problemSetTable.refreshTable();
            this.$(".set-id a").truncate({width: 120});
        },
        render: function () {
            this.$el.html($("#problem-set-manager-template").html());
            this.problemSetTable = new CollectionTableView({columnInfo: this.cols, collection: this.problemSets, 
                                paginator: {page_size: 10, button_class: "btn btn-default", row_class: "btn-group"}});
            this.problemSetTable.render().$el.addClass("table table-bordered table-condensed");
            this.$el.append(this.problemSetTable.el);
            this.problemSets.trigger("hide-show-all-sets","hide");
            this.$(".set-id a").truncate({width: 120});
            MainView.prototype.render.apply(this);
            return this;
        },
        getState: function () {
            return {};
        },
        updateTable: function() {
            if(this.problemSetTable){
                this.problemSetTable.render();
            }
        },
        addProblemSet: function (){
            var dateSettings = util.pluckDateSettings(this.settings);
            if (! this.addProblemSetView){
                (this.addProblemSetView = new AddProblemSetView({problemSets: this.problemSets,dateSettings: dateSettings})).render();
            } else {
                this.addProblemSetView.setModel(new ProblemSet({},dateSettings)).render().open();
            }
        },
        deleteSet: function(set){
            var del = confirm("Are you sure you want to delete the set " + set.get("set_id") + "?");
            if(del){
                this.problemSets.remove(set);
                this.problemSetTable.updateTable();
                this.problemSetTable.updatePaginator();
                
            }
        },
        set: function(opts){  // sets a general parameter (Perhaps put this in MainView)
            var self = this;
            _(opts).chain().keys().each(function(key){
                self[key] = opts[key];
            });
        },
        filterProblemSets: function (evt) {
            this.problemSetTable.filter($(evt.target).val()).render();
            this.$(".num-users").html(this.problemSetTable.getRowCount() + " of " + this.problemSets.length + " users shown.");
        },
        clearFilterText: function () {
            $("input.filter-text").val("");
            this.problemSetTable.filter("").render();
            this.$(".num-users").html(this.problemSetTable.getRowCount() + " of " + this.problemSets.length + " users shown.");
        },
        tableSetup: function () {
            var self = this;
            this.cols = [{name: "Delete", key: "delete", classname: "delete-set", 
                stickit_options: {update: function($el, val, model, options) {
                    $el.html($("#delete-button-template").html());
                    $el.children(".btn").on("click",function() {self.deleteSet(model);});
                }}},
                {name: "Set Name", key: "set_id", classname: "set-id", editable: false, datatype: "string",
                    stickit_options: {update: function($el, val, model, options) {
                        $el.html("<a href='#' class='goto-set' data-setname='"+val+"'>" + val + "</a>");
                        $el.children("a").on("click",function() {
                            self.eventDispatcher.trigger("show-problem-set",$(this).data("setname"));
                        });}
                    }
                },
                {name: "Users Assign.", key: "assigned_users", classname: "users-assigned", editable: false, datatype: "integer",
                    stickit_options: {onGet: function(val){
                        return val.length + "/" + self.users.length;
                    }},
                    sort_function: function(val){ return val.length;}
                    },
                {name: "Num. of Probs.", key: "problems", classname: "num-problems", editable: false, datatype: "integer",
                    stickit_options: {
                        update: function($el,val,model,options){
                            $el.html("<a href='/webwork2/" + config.courseSettings.course_id +"/" +
                                    model.get("set_id") + "/'>" + val.length + "</a>")
                        }},

                    sort_function: function(val){
                        return val.length;
                    }    
                },
                {name: "Reduced Scoring", key: "enable_reduced_scoring", datatype: "boolean",
                        classname: ["enable-reduced-scoring","yes-no-boolean-select"]},
                {name: "Visible", key: "visible", classname: ["is-visible","yes-no-boolean-select"], datatype: "boolean"},
                {name: "Open Date", key: "open_date", classname: ["open-date","edit-datetime"], 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Red. Scoring Date", key: "reduced_scoring_date", classname: ["reduced-scoring-date","edit-datetime"], 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Due Date", key: "due_date", classname: ["due-date","edit-datetime"], 
                        editable: false, datatype: "integer", use_contenteditable: false},
                {name: "Answer Date", key: "answer_date", classname: ["answer-date","edit-datetime"], 
                        editable: false, datatype: "integer", use_contenteditable: false}
            ];

        },
        getHelpTemplate: function () {
            return $("#problem-sets-manager-help-template").html();
        },
        messageTemplate: _.template($("#problem-sets-manager-messages-template").html()),
        setMessages: function(){
            var self = this;

            this.problemSets.on({
                add: function (_set){
                    _set.save();
                    _set.problems.on({
                        "change:value": function(prob){ self.changeProblemValueEvent(prob,_set)},
                        add: function(prob){ self.addProblemEvent(prob,_set)},
                        sync: function(prob){ self.syncProblemEvent(prob,_set)},
                    });
                    _set.changingAttributes={add: ""};
                },
                remove: function(_set){
                    _set.destroy({success: function() {
                        self.eventDispatcher.trigger("add-message",{type:"success",
                            short: self.messageTemplate({type:"set_removed",opts:{setname: _set.get("set_id")}}),
                            text: self.messageTemplate({type: "set_removed_details",opts:{setname: _set.get("set_id")}})});
                               
                       // update the assignmentDates to delete the proper assignments

                        self.assignmentDates.remove(self.assignmentDates.filter(function(assign) { 
                            return assign.get("problemSet").get("set_id")===_set.get("set_id");}));

                    }});
                },
                "change:due_date change:open_date change:answer_date change:reduced_scoring_date": function(_set){
                    self.assignmentDates.chain().filter(function(assign) { 
                            return assign.get("problemSet").get("set_id")===_set.get("set_id");})
                        .each(function(assign){
                            assign.set("date",moment.unix(assign.get("problemSet").get(assign.get("type").replace("-","_")+"_date"))
                                .format("YYYY-MM-DD"));
                        });
                },
                "change:problems": function(_set){
                    _set.save();
                },
                "set_date_error": function(_opts, model){
                    self.eventDispatcher.trigger("add-message",{type: "danger",
                        short: self.messageTemplate({type: "date_set_error", opts: _opts}),
                        text: self.messageTemplate({type: "date_set_error", opts: _opts})
                    });
                    _(model.changed).chain().keys().each(function(key) {
                        model.set(key,model.changingAttributes[key]);
                    })
                },
                change: function(_set){
                    _set.changingAttributes=_.pick(_set._previousAttributes,_.keys(_set.changed));
                },
                sync: function(_set){
                    _(_set.changingAttributes||{}).chain().keys().each(function(key){ 
                        switch(key){
                            case "problems":
                                self.eventDispatcher.trigger("add-message",{type: "success", 
                                    short: self.messageTemplate({type:"set_added",opts:{setname: _set.get("set_id")}}),
                                    text: attr.msg});
                                break;
                            case "problem_added": 
                                self.eventDispatcher.trigger("add-message",{type: "success", 
                                    short: self.messageTemplate({type:"problem_added",opts:{setname: _set.get("set_id")}}),
                                    text: self.messageTemplate({type:"problem_added_details",opts:{setname: _set.get("set_id")}})});
                                break;
                            case "problems_reordered": 
                                self.eventDispatcher.trigger("add-message",{type: "success", 
                                    short: self.messageTemplate({type:"problems_reordered",opts:{setname: _set.get("set_id")}}),
                                    text: self.messageTemplate({type:"problems_reordered_details",opts:{setname: _set.get("set_id")}})});
                                break;
                            case "problem_deleted": 
                                self.eventDispatcher.trigger("add-message",{type: "success", 
                                    short: self.messageTemplate({type:"problem_deleted",opts:{setname: _set.get("set_id")}}),
                                    text: self.messageTemplate({type: "problem_deleted_details", opts: _set.changingAttributes[key]})});
                                break;
                            case "assigned_users":
                                self.eventDispatcher.trigger("add-message",{type: "success",
                                    short: self.messageTemplate({type:"set_saved",opts:{setname:_set.get("set_id")}}), 
                                    text: self.messageTemplate({type:"set_assigned_users_saved",opts:{setname:_set.get("set_id")}})}); 
                                break;
                            case "add":
                                self.eventDispatcher.trigger("add-message",{type: "success", 
                                    short: self.messageTemplate({type:"set_added",opts:{setname: _set.get("set_id")}}),
                                    text: self.messageTemplate({type: "set_added_details",opts:{setname: _set.get("set_id")}})});
                                self.assignmentDates.add(new AssignmentDate({type: "open", problemSet: _set,
                                    date: moment.unix(_set.get("open_date")).format("YYYY-MM-DD")}));
                                self.assignmentDates.add(new AssignmentDate({type: "due", problemSet: _set,
                                    date: moment.unix(_set.get("due_date")).format("YYYY-MM-DD")}));
                                self.assignmentDates.add(new AssignmentDate({type: "answer", problemSet: _set,
                                    date: moment.unix(_set.get("answer_date")).format("YYYY-MM-DD")}));

                                break;    
                            default:
                                var _old = key.match(/date$/) ? moment.unix(_set.changingAttributes[key]).format("MM/DD/YYYY [at] hh:mmA")
                                             : _set.changingAttributes[key];
                                var _new = key.match(/date$/) ? moment.unix(_set.get(key)).format("MM/DD/YYYY [at] hh:mmA") : _set.get(key);
                                self.eventDispatcher.trigger("add-message",{type: "success", 
                                    short: self.messageTemplate({type:"set_saved",opts:{setname:_set.get("set_id")}}),
                                    text: self.messageTemplate({type:"set_saved_details",opts:{setname:_set.get("set_id"),key: key,
                                        oldValue: _old, newValue: _new}})});
                        } // switch 
                }); // .each
                } // sync
            }); // this.problemSets.on

                    /* This sets the events for the problems (of type ProblemList) in each problem Set */

            this.problemSets.each(function(_set) {
                _set.problems.on({
                    "change:value": function(prob){ self.changeProblemValueEvent(prob,_set)},
                    add: function(prob){ self.addProblemEvent(prob,_set)},
                    sync: function(prob){ self.syncProblemEvent(prob,_set)},
                });
            });
        }, // setMessages
        changeProblemValueEvent: function (prob,_set){    // not sure this is actually working.
            if(typeof(_set.changingAttributes.problem_added)==="undefined"){
                _set.changingAttributes={"value_changed": {oldValue: prob._previousAttributes.value, 
                    newValue: prob.get("value"), name: _set.get("set_id"), problem_id: prob.get("problem_id")}}
                }
        },
         addProblemEvent: function(prob,_set){
            _set.changingAttributes={"problem_added": ""};
        },
        syncProblemEvent: function(prob,_set){
            _(_set.changingAttributes||{}).chain().keys().each(function(key){ 
                switch(key){
                    case "value_changed": 
                        self.messagePane.addMessage({type: "success", 
                            short: config.msgTemplate({type:"set_saved",opts:{setname: _set.get("set_id")}}),
                            text: config.msgTemplate({type: "problems_values_details", opts: problems.changingAttributes[key]})});
                        break;
                    
                }
            });
        }
        
        
        
    });

    var AddProblemSetView = ModalView.extend({
        initialize: function (options) {
            _.bindAll(this,"render","addNewSet");
            this.model = new ProblemSet({},options.dateSettings);

            _.extend(options, {template: $("#add-hw-set-template").html(), 
                templateOptions: {name: config.courseSettings.user},
                buttons: {text: "Add New Set", click: this.addNewSet}});
            this.constructor.__super__.initialize.apply(this,[options]); 

            this.problemSets = options.problemSets; 
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
        validateName: function(evt){
            if (evt.keyCode==13){
                this.addNewSet();
            }
            var errorMsg = this.model.preValidate("set_id",$(evt.target).val());
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
    return ProblemSetsManager;

});