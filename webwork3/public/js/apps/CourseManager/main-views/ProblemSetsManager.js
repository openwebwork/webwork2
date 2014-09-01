/**
 *  This view has a listing of all the HW sets (similar to the old Homework Editor)
 *
 */

define(['backbone', 'underscore','views/MainView', 'views/CollectionTableView','config','apps/util',
    'views/ModalView','models/ProblemSet','models/AssignmentDate','moment'], 
function(Backbone, _,MainView,CollectionTableView,config,util,ModalView,ProblemSet,AssignmentDate,moment){


var ProblemSetsManager = MainView.extend({
    initialize: function (options) {
        MainView.prototype.initialize.call(this,options);
        _.bindAll(this, 'render','addProblemSet','clearFilterText','deleteSets','update','syncProblemEvent');  // include all functions that need the this object
        var self = this;

        this.state.on({
            "change:filter_string": function () {
                console.log(self.state.get("filter_string"))
                self.problemSetTable.set(self.state.pick("filter_string")).updateTable();
                self.$(".num-users").html(self.problemSetTable.getRowCount() + " of " 
                        + self.problemSets.length + " users shown.");
                self.update();
            },
            "change:show_time": function(){
                self.showTime(self.state.get("show_time"));
            }
        });

        this.tableSetup();

        this.problemSetTable = new CollectionTableView({columnInfo: this.cols, collection: this.problemSets, 
                classes: "problem-set-manager-table", row_id_field: "set_id", 
                table_classes: "problem-set-manager-table table table-bordered table-condensed",
                paginator: {page_size: this.state.get("page_size"), button_class: "btn btn-default", 
                                row_class: "btn-group"}});

        this.problemSetTable.on({
            "page-changed":function(num){
                self.state.set("current_page",num);
                console.log(self.state.attributes);
                self.update();},
            "table-sorted":function(info){
                self.state.set({sort_class: info.classname, sort_direction: info.direction});
                self.update();},
            "selected-row-changed": function(rowIDs){
                self.state.set({selected_rows: rowIDs});}
        });
        
        this.changeSetPropView = new ChangeSetPropertiesView({settings: this.settings,problemSets: this.problemSets});
        this.changeSetPropView.on("modal-opened",function (){
            self.state.set("set_prop_modal_open",true);
        }).on("modal-closed",function(){
            self.state.set("set_prop_modal_open",false);
            self.render(); // for some reason the checkboxes don't stay checked. 
        })

        this.problemSets.on({
            "add": this.update,
            "remove": this.update,
            "change:enable_reduced_scoring":this.update
        });
        this.setMessages();
    },
    events: {
        "click .add-problem-set-button": "addProblemSet",
        'click button.clear-filter-button': 'clearFilterText',
        "click a.show-rows": function(evt){ 
            this.showRows(evt);
            this.problemSetTable.updateTable();
            this.update();
        },
        "click a.change-set-props": "showChangeProps",
        "click a.delete-sets-button": "deleteSets",
        "change td.select-problem-set input[type='checkbox']": "updateSelectedSets",
        "change th input[type='checkbox']": "selectAll",
    },
    render: function () {
        var self = this;
        this.$el.html($("#problem-set-manager-template").html());
        this.problemSetTable.render();
        this.$el.append(this.problemSetTable.el);
        var opts = this.state.pick("page_size","filter_string","current_page","selected_rows");
        if(this.state.get("sort_class")&&this.state.get("sort_direction")){
            _.extend(opts,{sort_info: this.state.pick("sort_direction","sort_class")});
        }
        this.showRows(this.state.get("page_size"));
        this.problemSetTable.set(opts).updateTable();
        this.stickit(this.state,this.bindings);

        this.problemSets.trigger("hide-show-all-sets","hide");
        

        MainView.prototype.render.apply(this);
        
        if(this.state.get("set_prop_modal_open")){
            this.changeSetPropView.setElement(this.$(".modal-container"))
                .set({set_names: this.problemSetTable.getVisibleSelectedRows()}).render();
        }
        this.showTime(this.state.get("show_time"));        
        this.update();
        return this;
    },
    update: function (){
        if(this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}")){
            this.$("td:has(input.enable-reduced-scoring),td.reduced-scoring-date,th.enable-reduced-scoring,th.reduced-scoring-date")
                .removeClass("hidden");
        } else {
            this.$("td:has(input.enable-reduced-scoring),td.reduced-scoring-date,th.enable-reduced-scoring,th.reduced-scoring-date")
                .addClass("hidden");
        }
        this.problemSetTable.refreshTable();
        return this;
    },
    bindings: { 
        ".filter-text": "filter_string",
        ".show-time-toggle": "show_time"
    },
    showChangeProps: function(){
        var setIDs = this.problemSetTable.getVisibleSelectedRows();
        if(setIDs.length>0){
            this.changeSetPropView.setElement(this.$(".modal-container"))
                .set({set_names: setIDs}).render();
        } else {
            this.eventDispatcher.trigger("add-message",{type: "danger",
                    short: this.messageTemplate({type: "empty_selected_sets_error"}),
                    text: this.messageTemplate({type: "empty_selected_sets_error"})
                });
        }
    },
    showTime: function(_show){
        config.changeClass({state: _show, els: this.$(".open-date,.due-date,.reduced-scoring-date,.answer-date"), 
                remove_class: "edit-datetime", add_class: "edit-datetime-showtime"})
        this.problemSetTable.refreshTable();
    },
    getDefaultState: function () {
        return {filter_string: "", current_page: 0, page_size: this.settings.getSettingValue("ww3{pageSize}") || 10,
            sort_class: "", sort_direction: "", show_time: false, selected_rows: []};
    },
    addProblemSet: function (){
        var self = this;
        var problemSetView = new AddProblemSetView(_(this).pick("settings","users","problemSets"))
                    .setElement(this.$(".modal-container")).render()
                    .on("modal-closed",function(){
                        self.update();
                    })

    },
    updateSelectedSets: function (evt){
        var selectedSets = this.problemSetTable.getVisibleSelectedRows()
            , setID = $(evt.target).closest("tr").children("td.set-id").text()
            , sets = $(evt.target).prop("checked")?_(selectedSets).union([setID]):_(selectedSets).without(setID);
        this.state.set("selected_rows",_.compact(sets)); // compact removes empty set id's which pop up from time to time
    },
    getSelectedSets: function () {
        return $.makeArray(this.$("tbody td.select-problem-set input[type='checkbox']:checked").map(function(i,v) {
            return $(v).closest("tr").children("td.set-id").text();}));
    },
    deleteSets: function(){
        var setIDs = this.problemSetTable.getVisibleSelectedRows()
            , self = this
            , del;
        var setsToDelete = this.problemSets.filter(function(u){ return _(setIDs).contains(u.get("set_id"));});
        if (setIDs.length==0){
            alert("You haven't selected any sets to delete."); //I18N
            return;
        } else {
            del = confirm("Are you sure you want to delete the set" + (setIDs.length==1?" ":"s ") + setIDs.join(", ") + "?");
            if(del){
                _(setIDs).each(function(_set){
                    self.problemSets.remove(_set);                
                });
                this.update();
            }
        }
    },  
    showRows: function(arg){
        this.state.set("page_size", _.isNumber(arg) || _.isString(arg) ? parseInt(arg) : $(arg.target).data("num"));
        this.$(".show-rows i").addClass("not-visible");
        this.$(".show-rows[data-num='"+this.state.get("page_size")+"'] i").removeClass("not-visible")
        this.problemSetTable.set({page_size: this.state.get("page_size")});
    },
    set: function(opts){  // sets a general parameter (Perhaps put this in MainView)
        var self = this;
        _(opts).chain().keys().each(function(key){
            self[key] = opts[key];
        });
    },
    clearFilterText: function () {
        this.state.set("filter_string","");
    },
    tableSetup: function () {
        var self = this;
        this.cols = [{name: "Select", key: "_select_row", classname: "select-set"},
            {name: "Set Name", key: "set_id", classname: "set-id", editable: false, datatype: "string",
                stickit_options: {update: function($el, val, model, options) {
                    $el.html("<a href='#' onclick='return false' class='goto-set' data-setname='"+val+"'>" + val + "</a>");
                    $el.children("a").on("click",function() {
                        self.eventDispatcher.trigger("show-problem-set",$(this).data("setname"));
                    });}
                }
            },
            {name: "Users Assign.", key: "assigned_users", classname: "users-assigned", editable: false, datatype: "integer",
                value: function(model){ return model.get("assigned_users").length;},
                display: function(val){
                    return val+ "/" + self.users.length;}
                },
            {name: "Num. of Probs.", key: "problems", classname: "num-problems", editable: false, datatype: "integer",
                value: function(model){ return model.get("problems").length||0}},
            {name: "Reduced Scoring", key: "enable_reduced_scoring", datatype: "boolean",
                    classname: "enable-reduced-scoring"},
            {name: "Visible", key: "visible", classname: "is-visible", datatype: "boolean"},
            {name: "Open Date", key: "open_date", classname: "open-date edit-datetime", 
                    editable: false, datatype: "integer", use_contenteditable: false},
            {name: "Red. Scoring Date", key: "reduced_scoring_date", classname: "reduced-scoring-date edit-datetime", 
                    editable: false, datatype: "integer", use_contenteditable: false,
                    sort_function: function(val,model){return model.get("enable_reduced_scoring") ? val : 0;}},
            {name: "Due Date", key: "due_date", classname: "due-date edit-datetime", 
                    editable: false, datatype: "integer", use_contenteditable: false},
            {name: "Answer Date", key: "answer_date", classname: "answer-date edit-datetime", 
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
                _set._network={add: ""};
            },
            remove: function(_set){
                _set.destroy({success: function() {
                    self.eventDispatcher.trigger("add-message",{type:"success",
                        short: self.messageTemplate({type:"set_removed",opts:{setname: _set.get("set_id")}}),
                        text: self.messageTemplate({type: "set_removed_details",opts:{setname: _set.get("set_id")}})});
                           
                   // update the assignmentDates to delete the proper assignments

                    self.assignmentDates.remove(self.assignmentDates.filter(function(assign) { 
                        return assign.get("problemSet").get("set_id")===_set.get("set_id");}));
                    self.problemSetTable.updateTable();
                    self.update();
                }});
            },
            "change:due_date change:open_date change:answer_date change:reduced_scoring_date": function(_set){
                _set.adjustDates();
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
                _(_set._network).chain().keys().each(function(key){ 
                    switch(key){
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
                            self.problemSetTable.set({filter_string: self.state.get("filter_string")}).updateTable();
                            delete _set._network;
                            break;    
                    }
                });
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
        _set.changingAttributes={"value_changed": {oldValue: prob._previousAttributes.value, 
            newValue: prob.get("value"), name: _set.get("set_id"), problem_id: prob.get("problem_id")}};
            
    },
    addProblemEvent: function(prob,_set){
        _set.changingAttributes={"problem_added": ""};
    },
    syncProblemEvent: function(prob,_set){
        var self = this;
        _(_set.changingAttributes||{}).chain().keys().each(function(key){ 
            switch(key){
                case "value_changed": 
                    self.eventDispatcher.trigger("add-message",{type: "success", 
                        short: self.messageTemplate({type:"set_saved",opts:{setname: _set.get("set_id")}}),
                        text: self.messageTemplate({type: "problems_values_details", 
                            opts: _.extend({set_id:_set.get("set_id")},_set.changingAttributes[key])})});
                    break;
                
            }
        });
    }
});

var ChangeSetPropertiesView = ModalView.extend({
    initialize: function(options){
        var self = this;
        _(this).bindAll("saveChanges");
        _(this).extend(_(options).pick("problemSets","settings"));
        this.setNames = [];
        this.model = new ProblemSet({},util.pluckDateSettings(this.settings));
        this.model.show_reduced_scoring=true;
        this.model.setDefaultDates();
        this.model.on("change:enable_reduced_scoring",function(){
            if(self.model.get("enable_reduced_scoring")){
                self.$(".reduced-scoring-date").closest("tr").removeClass("hidden");
                // set the reduced_scoring_date to be the custom amount of time before the due_date
                self.model.set("reduced_scoring_date", 
                    moment.unix(self.model.get("due_date"))
                        .subtract(self.model.dateSettings["pg{ansEvalDefaults}{reducedScoringPeriod}"],"minutes")
                        .unix());
            } else {
                self.$(".reduced-scoring-date").closest("tr").addClass("hidden");
            }
        }).on("change:open_date change:due_date change:reduced_scoring_date change:answer_date", function (){
            self.model.adjustDates();
        });

        _(options).extend({
            modal_header: "Change Properties for Multiple Sets",
            modal_body: $("#change-set-props-template").html(),
            modal_action_button_text: "Save Changes"
        })

        ModalView.prototype.initialize.apply(this,[options]);
    },
    render: function (){
        ModalView.prototype.render.apply(this);
        this.$(".set-names").text(this.setNames.join(", "));
        if(!this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}")){
            this.$(".reduced-scoring").closest("tr").addClass("hidden");
        }
        this.stickit();
    },
    set: function(options){
        this.setNames = options.set_names;
        return this;
    },
    bindings: {
            ".open-date" : "open_date",
            ".due-date" : "due_date",
            ".answer-date": "answer_date",
            ".prob-set-visible": "visible",
            ".reduced-scoring": "enable_reduced_scoring",
            ".reduced-scoring-date": "reduced_scoring_date"
    },
    // this is added to the parentEvents in ModalView to create the entire events object. 
    childEvents: {
        "click .action-button": "saveChanges"
    },
    saveChanges: function(){
        var self = this;
        _(this.setNames).each(function(setID){
            self.problemSets.findWhere({set_id: setID})
                .set(self.model.pick("open_date","due_date","answer_date","visible","enable_reduced_scoring","reduced_scoring_date"));
        })
        this.$(".change-set-props-modal").modal("hide");
    }
});

var ChangeSetPropertiesView = ModalView.extend({
    initialize: function(options){
        var self = this;
        _(this).bindAll("saveChanges");
        _(this).extend(_(options).pick("problemSets","settings"));
        this.setNames = [];
        this.model = new ProblemSet({},util.pluckDateSettings(this.settings));
        this.model.show_reduced_scoring=true;
        this.model.setDefaultDates();
        this.model.on("change:enable_reduced_scoring",function(){
            if(self.model.get("enable_reduced_scoring")){
                self.$(".reduced-scoring-date").closest("tr").removeClass("hidden");
                // set the reduced_scoring_date to be the custom amount of time before the due_date
                self.model.set("reduced_scoring_date", 
                    moment.unix(self.model.get("due_date"))
                        .subtract(self.model.dateSettings["pg{ansEvalDefaults}{reducedScoringPeriod}"],"minutes")
                        .unix());
            } else {
                self.$(".reduced-scoring-date").closest("tr").addClass("hidden");
            }
        }).on("change:open_date change:due_date change:reduced_scoring_date change:answer_date", function (){
            self.model.adjustDates();
        });

        _(options).extend({
            modal_header: "Change Properties for Multiple Sets",
            modal_body: $("#change-set-props-template").html(),
            modal_action_button_text: "Save Changes"
        })

        ModalView.prototype.initialize.apply(this,[options]);
    },
    render: function (){
        ModalView.prototype.render.apply(this);
        this.$(".set-names").text(this.setNames.join(", "));
        if(!this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}")){
            this.$(".reduced-scoring-date").closest("tr").addClass("hidden");
            this.$(".reduced-scoring").closest("tr").addClass("hidden");
        } else {
            this.$(".reduced-scoring-date").closest("tr").removeClass("hidden");
            this.$(".reduced-scoring").closest("tr").removeClass("hidden");
        }
        this.stickit();
    },
    set: function(options){
        var self = this;
        this.setNames = options.set_names;
        // get the common properties of the problem sets and set the model to these.
        this.selectedSets = this.problemSets.filter(function(_set){
            return _(self.setNames).contains(_set.get("set_id"));
        });
        var timeDue = this.settings.getSettingValue("pg{timeAssignDue}");
        var today = moment(moment().format("MM/DD/YYYY")+" " + timeDue,"MM/DD/YYYY hh:mmA");
        var dateTypes = ["open_date","reduced_scoring_date","due_date","answer_date"];
        var dateValues = _(dateTypes).map(function(prop){
            var values = _(self.selectedSets).chain().pluck("attributes").pluck(prop).value();
            // find the mean date of all of the selected dates
            var values2 = parseInt(_.reduce(values, function(num1, num2){ return num1 + num2; }, 0)/values.length);
            return moment.unix(values2).hours(today.hours()).minutes(today.minutes()).unix();
        });
        var RS_and_visible = ["enable_reduced_scoring","visible"];
        var RV_values = _(RS_and_visible).map(function(v){
            return _(self.selectedSets).chain().pluck("attributes").pluck(v).every().value();
        });
        this.model.set(_.extend(_.object(dateTypes,dateValues),_.object(RS_and_visible,RV_values)));
        return this;
    },
    bindings: {
            ".open-date" : "open_date",
            ".due-date" : "due_date",
            ".answer-date": "answer_date",
            ".prob-set-visible": "visible",
            ".reduced-scoring": "enable_reduced_scoring",
            ".reduced-scoring-date": "reduced_scoring_date"
    },
    // this is added to the parentEvents in ModalView to create the entire events object. 
    childEvents: {
        "click .action-button": "saveChanges"
    },
    saveChanges: function(){
        var self = this;
        _(this.setNames).each(function(setID){
            self.problemSets.findWhere({set_id: setID})
                .set(self.model.pick("open_date","due_date","answer_date","visible","enable_reduced_scoring","reduced_scoring_date"));
        })
        this.$(".change-set-props-modal").modal("hide");
    }
});

var AddProblemSetView = ModalView.extend({
    initialize: function (options) {
        _.bindAll(this,"render","addNewSet","validateName");
        _(this).extend(_(options).pick("settings","problemSets","users"))
        this.model = new ProblemSet({},options.dateSettings);
        this.model.problemSets = options.problemSets; 

        _(options).extend({
            modal_header: "Add Problem Set to Course",
            modal_body: _.template($("#add-hw-set-template").html(),{users: [config.courseSettings.user]}),
            modal_action_button_text: "Add New Set"
        })

        ModalView.prototype.initialize.apply(this,[options]);
    },
    render: function () {
        ModalView.prototype.render.apply(this);
        this.stickit();

        return this;
    },
    setModel: function(_model){
        this.model = _model;
        return this;
    },
    bindings: {
        ".problem-set-name": "set_id"
    },
    childEvents: {
        "keyup .problem-set-name": "validateName",
        "click .action-button": "addNewSet"
    },
    validateName: function(evt){
        if (evt && evt.keyCode==13){
            this.addNewSet();
        }
        var errorMsg = this.model.preValidate("set_id",this.model.get("set_id"));
        if(this.model.problemSets.findWhere({set_id: this.model.get("set_id")}))
            errorMsg = config.messageTemplate({type:"set_name_already_exists",opts: {set_id: this.model.get("set_id")}});

        if(errorMsg){
            this.$(".problem-set-name").css("background","rgba(255,0,0,0.5)");
            this.$(".problem-set-name-error").html(errorMsg);
            this.$(".action-button").attr("disabled","disabled")
            return false;
        } else {
            this.$(".problem-set-name").css("background","none");
            this.$(".problem-set-name-error").html("");
            this.$(".action-button").removeAttr("disabled");
            return true;
        }
    },
    addNewSet: function() {
        var valid = this.validateName();
        if(valid){
            var users = this.$(".assign-to-all-users").prop("checked") ? 
                this.users.pluck("user_id") : [config.courseSettings.user]; 
            this.model.setDefaultDates(moment().add(10,"days")).set("assigned_users",users);
            this.problemSets.add(this.model);
            this.close();
        }
    }

});
return ProblemSetsManager;

});