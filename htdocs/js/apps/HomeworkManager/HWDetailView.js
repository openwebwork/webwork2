/**
 *  This is the HWDetailView, which is part of the HomeworkManagmentView.  The view contains the interface to all of the
 *  details of a given homework set including the changing of HWSet properties and assigning of users. 
 *
 *  One must pass a ProblemSet as a model to this.  
 * 
 **/


define(['Backbone', 
    'underscore',
    '../../lib/webwork/views/EditableCell',
    '../../lib/webwork/views/ProblemListView',
    '../../lib/webwork/models/ProblemList'], 
    function(Backbone, _,EditableCell,ProblemListView,ProblemList){
	var HWDetailView = Backbone.View.extend({
        className: "set-detail-view",
        tagName: "div",
        initialize: function () {
            _.bindAll(this,'render','changeHWSet','renderProblems','updateNumProblems');
            this.parent = this.options.parent;
            this.dispatcher = _.clone(Backbone.Events);
            this.render();
        },
        changeHWSet: function (setName)
        {
            var self = this;
            $("#view-header-list div[data-view='problem-set']").html("Problem Set Details for " + setName);

            $("#problem-set-tabs a:first").tab("show");  // shows the problems 

            // this.model will be a ProblemSet 
        	this.model = this.collection.find(function(model) {return model.get("set_id")===setName;});

            
            if(this.model.problems){
                console.log("changing the HW Set to " + setName);
                this.renderProblems();
                this.model.problems.on("add",function (){
                    console.log("Added a Problem");
                    self.parent.announce.addMessage("Problem Added to set: " + self.model.get("set_id"));
                });

                new HWPropertiesView({el: $("#property-tab"), model: this.model});


                /*this.model.countSetUsers();
                this.model.on("countUsers",function(_assignedUsers){
                    console.log("in countUsers");
                    $("#num-users-assigned").html(_assignedUsers.length + " of " + self.parent.users.length);
                    $("#user-tab").html((new AssignUsersView({users: self.parent.users, assignedUsers: _assignedUsers, 
                                            model: self.model})).el);

                }); */

                // This sets messages 
                this.model.problems.on("deleteProblem",function (setName,place) {
                    var str = "Problem #" + (place +1) + " Deleted from set: " + setName + " <br> "
                            + "To undo this, click the Undo button above the problem list. "; 
                    self.parent.announce.addMessage(str);
                });

                this.model.problems.on("remove",self.updateNumProblems);
            
            } else {
                this.model.problems = new ProblemList({type: "Problem Set", setName: setName});
                this.model.problems.on("fetchSuccess",function() {self.changeHWSet(setName)});
            }

            this.dispatcher.off("num-problems-shown");
            this.dispatcher.on("num-problems-shown", self.updateNumProblems);
        },
        render: function () {
            var self = this;
            this.$el.html(_.template($("#HW-detail-template").html()));
            // activate the tabs
            $('#problem-set-tabs a').click(function (e) {
                e.preventDefault();
                $(this).tab('show');
            });


            return this;
       
    	},
        renderProblems: function (){
            console.log("showing the problems for problem set " + this.model.get("set_id"));
            $("#prob-tab").html(_.template($("#problem-set-header").html(),{set: this.model.get("set_id")}));
            var plv = new ProblemListView({el: this.$("#list-of-problems"), parent: this, collection: this.model.problems,
                                        reorderable: true, deletable: true, draggable: false});
            plv.render();
        },
        updateNumProblems: function () {
            console.log("firing num-problems-shown");
            var num = this.$("li.problem").size();
            this.$("div.num-probs").html(num + " of " + this.model.problems.size() + " shown");
        }
    });

    var HWPropertiesView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this,'render');
            _.extend(this,this.options);
            this.render();
        },
        render: function () {
            // Update  the HW Properties Tab

            console.log("in HWPropertiesView render");

            this.$el.html(_.template($("#hwset-dates-tmpl").html()));


            this.$("#due-date-row").append( (new EditableCell({model : this.model, type: "datetime", property: "open_date"})).render().el);
            this.$("#due-date-row").append( (new EditableCell({model : this.model, type: "datetime", property: "due_date"})).render().el);
            this.$("#due-date-row").append( (new EditableCell({model : this.model, type: "datetime", property: "answer_date"})).render().el);

            this.$("#hwset-visible").html((new EditableCell({model: this.model, property: "visible"})).render().el);
            this.$("#reduced-credit").html((new EditableCell({model: this.model, property: "enable_reduced_scoring"})).render().el);

        }
    });

	var AssignUsersView = Backbone.View.extend({
		tagName: "div",
        template: _.template($("#selected-users-template").html()),
		initialize: function () {
			_.bindAll(this,'render','selectAll','assignToSelected');
			_.extend(this,this.options);
			this.render();
		},
		render: function ()  {
			var self = this;
			this.$el.html(_.template($("#users-assigned-tmpl").html()));

            var allUsers = this.users.sortBy(function(_user) { return _user.get("last_name");});

			_(allUsers).each(function(user,i) { 
                var cl = null;
                if (i<self.users.size()/3.0) { cl = self.$("#classlist-col1")} 
                else if (i<2*self.users.size()/3.0) {cl = self.$("#classlist-col2")}
                else {cl = self.$("#classlist-col3")}
				cl.append(self.template({user: user.get("user_id"), cid: user.cid, firstname: user.get("first_name"), 
                                            lastname: user.get("last_name")}));
            });

            this.$(".classlist-li").attr("checked",false);  // for some reason the check boxes are checked initially.

            // colors all previously assigned users and disables the checkbox.
            _(this.assignedUsers).each(function(_user){
                var checkbox = self.$(".classlist-li[data-username='"+ _user + "']");
                checkbox.parent().addClass("hw-assigned");
                checkbox.prop("disabled",true);
                checkbox.prop("checked",true);
            });

		},
        events: { "click #assign-to-selected-users-button": "assignToSelected",
                  "click #classlist-select-all": "selectAll"},
        assignToSelected: function ()
        {
            var users = _($("input:checkbox.classlist-li[checked='checked']")).map(function(v){ return $(v).data("username")});
            console.log(users)
            console.log("assigning to selected users");

            this.model.assignToUsers(_.difference(users,this.assignedUsers));
        },
        selectAll: function (){
            this.$(".classlist-li").attr("checked",this.$("#classlist-select-all").attr("checked")==="checked");
            _(this.assignedUsers).each(function(_user){
                self.$(".classlist-li[data-username='"+ _user + "']").prop("checked",true);
            });
        }

	});

	return HWDetailView;
});