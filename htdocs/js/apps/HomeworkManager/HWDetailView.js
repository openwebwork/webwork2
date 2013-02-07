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
    '../../lib/webwork/models/ProblemList',
    '../../lib/webwork/views/UserListView','config'], 
    function(Backbone, _,EditableCell,ProblemListView,ProblemList,UserListView,config){
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

                self.propertyView = new HWPropertiesView({el: $("#property-tab"), model: this.model});
                self.usersAssignedView = new AssignUsersView({users: self.parent.users, model: self.model});
                self.customizeUserAssignView = new CustomizeUserAssignView({users: self.parent.users, model: self.model});
                $("#num-users-assigned").html(length + " of " + self.parent.users.length);
                $("#user-assign-tab").html(self.usersAssignedView.el);
                $("#user-customize-tab").html(self.customizeUserAssignView.el);

                // This sets messages 
                this.model.problems.on("deleteProblem",function (setName,place) {
                    var str = "Problem #" + (place +1) + " Deleted from set: " + setName + " <br> "
                            + "To undo this, click the Undo button above the problem list. "; 
                    self.parent.announce.addMessage(str);
                });

                this.model.problems.on("remove",self.updateNumProblems);
                this.model.problems.on("change",function(model)
                {
                    // need a announcement here.  
                   // self.parent.announce.addMessage("Something changed. ");
                })

                this.model.on("usersAssigned",function(_users,setName){
                    self.parent.announce.addMessage("The following users are a assigned to set " + setName + " : " + _users.join(", "));
                    self.model.assignedUsers = _(_users).union(self.model.assignedUsers);
                    console.log(self.model.assignedUsers);
                    self.usersAssignedView.updateUserList();
                });
            
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
            $('#problem-set-tabs a').click(function (evt) {
                evt.preventDefault();

                switch($(evt.target).attr("href")){
                    case "#user-assign-tab":
                        self.usersAssignedView.render();
                        break;
                    case "#user-customize-tab":
                        self.customizeUserAssignView.render();
                        break;
                }
                

                $(this).tab('show');
            });


            return this;
       
    	},
        renderProblems: function (){
            console.log("showing the problems for problem set " + this.model.get("set_id"));
            $("#prob-tab").html(_.template($("#problem-set-header").html(),{set: this.model.get("set_id")}));
            var plv = new ProblemListView({el: this.$("#list-of-problems"), parent: this, collection: this.model.problems,
                                        reorderable: true, deletable: true, draggable: false, showPoints: true});
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


            this.$(".due-date-row").append( (new EditableCell({model : this.model, type: "datetime", property: "open_date"})).render().el);
            this.$(".due-date-row").append( (new EditableCell({model : this.model, type: "datetime", property: "due_date"})).render().el);
            this.$(".due-date-row").append( (new EditableCell({model : this.model, type: "datetime", property: "answer_date"})).render().el);

            this.$(".hwset-visible").html((new EditableCell({model: this.model, property: "visible"})).render().el);
            this.$(".reduced-credit").html((new EditableCell({model: this.model, property: "enable_reduced_scoring"})).render().el);

        }
    });

	var AssignUsersView = Backbone.View.extend({
		tagName: "div",
		initialize: function () {
			_.bindAll(this,'render','selectAll','assignToSelected','updateUserList');
			_.extend(this,this.options);
		},
		render: function ()  {
			var self = this;
            this.$el.html($("#users-assigned-tmpl").html());

            var allUsers = this.users.sortBy(function(_user) { return _user.get("last_name");});

            this.usersListView = new UserListView({users: allUsers, checked: false, el: this.$("#users-assigned-row")});
            this.updateUserList();
            return this;

		},
        events: { "click #assign-to-selected-users-button": "assignToSelected",
                  "click #classlist-select-all": "selectAll"},
        updateUserList: function () {
            this.usersListView.render();
            this.usersListView.highlightUsers(this.model.assignedUsers);
            this.usersListView.disableCheckboxForUsers(this.model.assignedUsers);
        },
        assignToSelected: function ()
        {
            var selectedUsers = _($("input:checkbox.classlist-li[checked='checked']")).map(function(v){ return $(v).data("username")});
            console.log(selectedUsers)
            console.log("assigning to selected users");

            this.model.assignToUsers(_.difference(selectedUsers,this.model.assignedUsers));
            this.model.assignedUsers = selectedUsers;
        },
        selectAll: function (){
            this.$(".classlist-li").attr("checked",this.$("#classlist-select-all").attr("checked")==="checked");
            _(this.model.assignedUsers).each(function(_user){
                self.$(".classlist-li[data-username='"+ _user + "']").prop("checked",true);
            });
        }

	});

    var CustomizeUserAssignView = Backbone.View.extend({
        tagName: "div",
        initialize: function () {
            _.bindAll(this,'render','selectAll','customizeSelected','unassignUsers');
            _.extend(this,this.options);
            this.render();
        },


        render: function() {
            this.$el.html($("#custom-assign-tmpl").html());
            this.openDate = new EditableCell({model : this.model, type: "datetime", property: "open_date", silent: true});
            this.dueDate = new EditableCell({model : this.model, type: "datetime", property: "due_date", silent: true});
            this.answerDate = new EditableCell({model : this.model, type: "datetime", property: "answer_date", silent: true});
            this.$(".due-date-row").append(this.openDate.render().el);
            this.$(".due-date-row").append(this.dueDate.render().el);
            this.$(".due-date-row").append(this.answerDate.render().el);

            var allUsers = this.users.sortBy(function(_user) { return _user.get("last_name");});

            this.usersListView = new UserListView({users: allUsers, checked: false, el: this.$("#custom-user-row")}).render();
            this.usersListView.highlightUsers(this.model.assignedUsers);
            return this;
        },
         events: {  "click #custom-save-changes": "customizeSelected",
                    "click #unassign-users": "unassignUsers",
                    "click #custom-select-all": "selectAll"},
        customizeSelected: function ()
        {
            var users = this.usersListView.getSelectedUsers();
            this.model.updateUserSet(users,this.openDate.getValue()+ " " + config.timezone, 
                this.dueDate.getValue()+ " " + config.timezone, this.answerDate.getValue()+ " " + config.timezone);
        },
        selectAll: function (){
            this.usersListView.checkAll(this.$("#custom-select-all").prop("checked"));
/*            this.$(".classlist-li").attr("checked",);
            _(this.assignedUsers).each(function(_user){
                self.$(".classlist-li[data-username='"+ _user + "']").prop("checked",true);
            });*/
        },
        unassignUsers: function(){
            var users = this.usersListView.getSelectedUsers();
            this.model.unassignUsers(users);
            this.model.assignedUsers = _.difference(this.model.assignedUsers,users);

        }
    });

	return HWDetailView;
});