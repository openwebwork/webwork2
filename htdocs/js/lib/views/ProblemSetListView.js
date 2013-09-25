/**
*  This view is the interface to the Library Tree and allows the user to easier navigate the Library. 
*
*  The this.collection object is a ProblemSetList
*  The following must be passed on initialization
*       users:  A UserList Backbone.Collection
*       settings:  A Settings Backbone.Collection
*
*/

define(['Backbone', 'underscore','models/ProblemSetList','models/ProblemSet','config',
            'views/ModalView', 'jquery-truncate'], 
function(Backbone, _,ProblemSetList,ProblemSet,config,ModalView){
	
    var ProblemSetListView = Backbone.View.extend({

    	initialize: function (){
    		_.bindAll(this,"render","addSet","deleteSet");
            var self = this;

            this.setViewTemplate = $("#set-view-template").html();
            this.template = _.template($("#problem-set-list-template").html());
            this.problemSets = this.options.problemSets; 
            this.users = this.options.users; 

            this.problemSets.on("add",this.render);
            this.problemSets.on("remove",this.render);

        },
        render: function ()
        {
            var self = this;
            console.log("in PSLV render");
            
            this.$el.html(this.template({loading: false}));
            this.problemSets.each(function (_model) {
                self.$("#probSetList").append((new SetView({model: _model, template: self.setViewTemplate,
                    numUsers: self.users.length})).render().el);
            });
            var _width = self.$el.width() - 70; 
            self.$(".set-name").truncate({width: _width}); //if the Problem Set Names are too long.  
           
            if (this.problemSets.size() === 0 ) {
                $("#set-list:nth-child(1)").after("<div id='zeroShown'>0 of 0 Sets Shown</div>")
            }

            self.$(".prob-set-container").height($(window).height()*.80);



        },
        events: {"click a.add-problem-set": "addSet",
                 "click a.delete-problem-set": "deleteSet"},
        addSet: function (evt){            
            if (! this.addProblemSetView){
                (this.addProblemSetView = new AddProblemSetView({problemSets: this.problemSets})).render();
            } else {
                this.addProblemSetView.setModel(new ProblemSet()).render().open();
            }

        },
        deleteSet: function () {
            if (! this.deleteProblemSetView){
                this.deleteProblemSetView = new DeleteProblemSetView({problemSets: this.problemSets});
                this.deleteProblemSetView.render();
            } else {
                this.deleteProblemSetView.open();
            }
        }
    });

    var SetView = Backbone.View.extend({
        tagName: "li",
        initialize: function() {
            _.bindAll(this,"render");
            this.$el.addClass("problem-set").addClass("btn").addClass("btn-small");
            this.template = this.options.template; 
            this.numUsers = this.options.numUsers;

        },
        render: function(){
            this.$el.html(this.template);
            this.$el.data("setname",this.model.get("set_id"));
            if(this.model.get("visible")==0){
                this.$el.addClass("not-visible");
            }
            this.stickit();
            return this;
        },
        bindings: {".set-name": "set_id", 
            ".num-users": { observe: "assigned_users",  
                onGet: function(value,options) { return "(" +value.length + "/" + this.numUsers + ")"; }}
        }

    });

    var AddProblemSetView = ModalView.extend({
        initialize: function () {
            _.bindAll(this,"render","addNewSet");
            this.model = new ProblemSet();


            _.extend(this.options, {template: $("#add-hw-set-template").html(), 
                templateOptions: {name: config.requestObject.user},
                buttons: {text: "Add New Set", click: this.addNewSet}});
            this.constructor.__super__.initialize.apply(this); 

            this.problemSets = this.options.problemSets; 

              /*  Not sure why the following doesn't pass the options along. 
              this.constructor.__super__.initialize.apply(this,
                {template: $("#modal-template").html(), templateOptions: {header: "<h3>Create a New Problem Set</h3>", 
                                saveButton: "Create New Set"}, modalBodyTemplate: $("#add-hw-set-template").html(),
                                modalBodyTemplateOptions: {name: config.requestObject.user}}); */
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
            var errorMessage = problemSet.preValidate('set_id', setname);
            if (errorMessage){
                this.$("#new-set-modal .modal-body").append("<div style='color:red'>The name of the set must contain only letters numbers, '.', _ and no spaces are allowed.");
                return;
            } */
 
            this.model.setDefaultDates(moment().add(10,"days")).set("assigned_users",[$("#hidden_user").val()]);
            console.log(this.model.attributes);
            console.log("adding new set");
            this.problemSets.add(this.model);
            this.close();
        }

    });

    var DeleteProblemSetView = ModalView.extend({
         initialize: function () {
            _.bindAll(this,"render","deleteSets");

            //var TempModel = new Backbone.Model.extend({defaults: {"deletedSets": ""}});
             var DeletedSets = Backbone.Model.extend({
              defaults: {
                "deletedSets": []
              }
            });

            this.model = new DeletedSets();

            this.allSets = this.options.problemSets; 

            _.extend(this.options, {template: $("#delete-hw-set-template").html(), title: "Select Sets to Delete",
                    templateOptions: {problemSets: this.problemSets},
                buttons: {text: "Delete Sets", click: this.deleteSets}});
            this.constructor.__super__.initialize.apply(this); 


        },

        // this doesn't look necessary.  Is it? 
        render: function () {
            this.constructor.__super__.render.apply(this); 

            return this;
        },
        deleteSets: function () {
            var self = this;
            console.log("deleting sets");
            console.log(this.model.attributes);

            // Why do this?  can't we just delete the selected sets from the this.allSets ?
            var setsToDelete = [];
            _(this.model.get("deletedSets")).each(function(set_name){
                setsToDelete = _(setsToDelete).union(self.allSets.findWhere({set_id: set_name}).cid);
            });
            console.log(setsToDelete);
            this.allSets.remove(setsToDelete);
            this.close();
        }, 
        bindings: { ".delete-problem-sets-list": { observe: "deletedSets", 
            selectOptions: {labelPath: "set_id", valuePath: "set_id", collection: "this.allSets" }}}
    })

    

    return ProblemSetListView;

});