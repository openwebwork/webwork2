/**
*  This view is the interface to the Library Tree and allows the user to easier navigate the Library. 
*
*  The this.collection object is a ProblemSetList
*
*/

define(['Backbone', 'underscore','../models/ProblemSetList','../models/ProblemSet','config','jquery-truncate'], 
function(Backbone, _,ProblemSetList,ProblemSet,config){
	
    var ProblemSetListView = Backbone.View.extend({

    	initialize: function (){
    		_.bindAll(this,"render","addDeleteSet","addSet","deleteSet");
            var self = this;
            _.extend(this,this.options);

            
            
            
            this.collection.on("problem-set-added",function(set) {
                    console.log("in PSLV problem-set-added");
                    self.$("#probSetList").append((new SetView({model: set})).render().el);
                    self.parent.dispatcher.trigger("problem-set-added", set);
            });
            this.collection.on("fetchSuccess", function () {
                self.render();
                self.parent.dispatcher.trigger("problem-sets-loaded");
            });

            this.collection.on("problem-set-deleted", function (set) {
                self.$(".problem-set").each(function(i,v){
                    if ($(v).data("setname")===set.get("set_id")){ $(v).remove();}
                })
            });
            this.render();
        },
        render: function ()
        {
            var self = this;
            if (this.viewType === "Instructor"){
                this.$el.html(_.template($("#hw-set-list-template").html()));
                this.$el.append(_.template($("#modal-template").html(), 
                    {header: "<h3>Create a new Homework Set</h3>", saveButton: "Create New Set", id: "new-set-modal"}));
            }
            if(this.collection.size()>0){
                this.$("a.link").on("click",this.addDeleteSet);
                this.$("#set-list").html("<div style='font-size:110%; font-weight:bold'>Homework Sets</div>" +
                    "<ul id='probSetList' class='btn-group btn-group-vertical'></ul>");
            
                this.collection.each(function (_model) {
                    self.$("#probSetList").append((new SetView({model: _model})).render().el);
                });
                var _width = self.$el.width() - 40; 
                self.$(".problem-set").truncate({width: _width}); //if the Problem Set Names are too long.  
               

            }


        },
        addDeleteSet: function (evt){
            var self = this;
            switch($(evt.target).data("link")){
                case "add-new-hw-set":
                    this.$("#new-set-modal .modal-body").html(_.template($("#add-hw-set-template").html(),{name : config.requestObject.user}));
                    this.$("#new-set-modal .btn-primary").html("Create New Set");
                    this.$("#new-set-modal").modal("show");
                    this.$("#new-set-modal .btn-primary").on('click',this.addSet);
                    break;
                case "delete-hw-set":
                    this.$("#new-set-modal .modal-body").html(_.template($("#delete-hw-set-template").html()));
                    this.$("#new-set-modal .btn-primary").html("Delete Set");

                    var sets = this.collection.map(function(set) { 
                        return "<li><input type='checkbox' data-setid='" + set.get("set_id") + "'>" + set.get("set_id") + "</li>"})
                    this.$("#new-set-modal .modal-body").append("<ul>" + sets.join("") + "</ul>");
                    this.$("#new-set-modal").modal("show");
                    this.$("#new-set-modal .btn-primary").on('click',this.deleteSet);
                    break;
            }


        },
        addSet: function () {
            // need to validate the set name
            var setname = $(".modal-body input:text").val();
            
            // set up the standard open and due dates first. 
            var timeAssignDue = this.parent.settings.getSettingValue("pg{timeAssignDue}");
            var timezone = this.parent.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");


            var today = XDate.today();
            var openDate = today.clone().addDays(7);
            var assignOpenPriorToDue = this.parent.settings.getSettingValue("pg{assignOpenPriorToDue}");
            var dueDate = openDate.clone().addMinutes(assignOpenPriorToDue);
            var answerAfterDueDate = this.parent.settings.getSettingValue("pg{answersOpenAfterDueDate}");
            var answerDate = dueDate.clone().addMinutes(answerAfterDueDate);
 

            // _openDate.toString("MM/dd/yyyy") + " at " + _openDate.toString("hh:mmtt")+ " " + tz[1];            

            var set = new ProblemSet({set_id: setname,
                answer_date: answerDate.toString("MM/dd/yyyy") + " at " + timeAssignDue + " " + timezone,
                open_date: openDate.toString("MM/dd/yyyy") + " at " + timeAssignDue + " " + timezone,
                due_date: dueDate.toString("MM/dd/yyyy") + " at " + timeAssignDue + " " + timezone
            });
            var errorMessage = set.preValidate('set_id', setname);
            if (errorMessage){
                this.$("#new-set-modal .modal-body").append("<div style='color:red'>The name of the set must contain only letters numbers, '.', _ and no spaces are allowed.");
                return;
            }
            set.set({"new_set_name":setname},{silent: true});
            this.collection.add(set);
            this.$("#new-set-modal").modal("hide");
        },
        deleteSet: function () {
            var deletedSets = _.toArray(this.$("#new-set-modal input:checkbox[checked='checked']")
                                    .map(function(i,v){return $(v).data("setid");}));
            console.log("deleting sets: " + deletedSets.join(","));

            var sets = this.collection.filter(function (set) { return _(deletedSets).indexOf(set.get("set_id"))>-1;});
            _(sets).each(function(set){set.destroy();});

            this.$("#new-set-modal").modal("hide");
        }
    });

    var SetView = Backbone.View.extend({
        tagName: "li",
        initialize: function() {
            _.bindAll(this,"render");
            this.$el.addClass("problem-set").addClass("btn").addClass("btn-small");
            

        },
        render: function(){
            this.$el.html(this.model.get("set_id"));
            this.$el.data("setname",this.model.get("set_id"));
            return this;
        }


    });

    

    return ProblemSetListView;

});