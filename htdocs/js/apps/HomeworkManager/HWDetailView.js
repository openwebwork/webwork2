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
    '../../lib/webwork/views/UserListView','config','bootstrap'], 
    function(Backbone, _,EditableCell,ProblemListView,ProblemList,UserListView,config){
	var HWDetailView = Backbone.View.extend({
        className: "set-detail-view",
        tagName: "div",
        initialize: function () {
            _.bindAll(this,'render','changeHWSet','updateNumProblems');
            this.parent = this.options.parent;
            this.problemsView = new ProblemsView({parent: this});
            this.usersAssignedView = new AssignUsersView({parent: this});
            this.propertiesView = new PropertySetDetailView({parent: this});
            this.customizeUserAssignView = new CustomizeUserAssignView({parent: this});
            
        },
        render: function () {
            var self = this;

            // all of the details of a problem set are in tabs.
            // problems : #list-of-problems
            // properties:  #property-tab
            // Assign to Users:  #user-assign-tab
            // customize set to users:  #user-customize-tab
            //
            // render the set only when it is visible.  

            this.$el.html(_.template($("#HW-detail-template").html()));
            // activate the tabs
            this.problemsView = new ProblemsView({parent: this, el: $("#problem-list-tab")});
            this.usersAssignedView = new AssignUsersView({parent: this, el: $("#user-assign-tab")});
            this.propertiesView = new PropertySetDetailView({parent: this, el: $("#property-tab")});
            this.customizeUserAssignView = new CustomizeUserAssignView({parent: this, el: $("#user-customize-tab")});
            
            $('#problem-set-tabs a').click(function (evt) {
                evt.preventDefault();
                $(this).tab('show');
            });

            $('a[href="#property-tab"]').on('shown', function (evt) {
                self.propertiesView.render();
            });
            $('a[href="#user-assign-tab"]').on('shown', function (evt) {
                self.usersAssignedView.render();
            });

            $('a[href="#user-customize-tab"]').on('shown', function (evt) {
                self.customizeUserAssignView.render();
            });


            return this;
       
        },
        changeHWSet: function (setName)
        {
            var self = this;
            $("#view-header-list div[data-view='problem-set']").html("Problem Set Details for " + setName)

            $("#problem-set-tabs a:first").tab("show");  // shows the problems 

            // this.model will be a ProblemSet 
        	this.model = this.collection.find(function(model) {return model.get("set_id")===setName;});

            
            if(this.model.problems){
                console.log("changing the HW Set to " + setName);
                this.problemsView.render();
                this.model.problems.on("add",function (){
                    console.log("Added a Problem");
                    self.parent.announce.addMessage("Problem Added to set: " + self.model.get("set_id"));
                });

                // This sets messages 
                this.model.problems.on("deleteProblem",function (setName,place) {
                    var str = "Problem #" + (place +1) + " deleted from set: " + setName + " <br> "
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

                this.model.problems.on("num-problems-shown", self.updateNumProblems);
            
            } else {
                this.model.problems = new ProblemList({type: "Problem Set", setName: setName});
                this.model.problems.on("fetchSuccess",function() {self.changeHWSet(setName)});
            }


        },
        updateNumProblems: function () {
            console.log("firing num-problems-shown");
            var num = this.$("li.problem").size();
            this.$("div.num-probs").html(num + " of " + this.model.problems.size() + " shown");
        }
    });

    var ProblemsView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this,'render');
            this.parent = this.options.parent;
        },
        render: function () {
            console.log("showing the problems for problem set " + this.parent.model.get("set_id"));
            $("#prob-tab").html(_.template($("#problem-set-header").html(),{set: this.parent.model.get("set_id")}));
            var plv = new ProblemListView({el: this.el, parent: this, collection: this.parent.model.problems,
                                        reorderable: true, deletable: true, draggable: false, showPoints: true});
            plv.render();  
        }
    });

    var PropertySetDetailView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this,'render');
            this.parent = this.options.parent;
        },
        render: function () {
            console.log(this.parent.model);
            this.$el.html(_.template($("#hwset-dates-tmpl").html()));
            this.$(".due-date-row").append( (new EditableCell({model : this.parent.model, type: "datetime", property: "open_date"})).render().el);
            this.$(".due-date-row").append( (new EditableCell({model : this.parent.model, type: "datetime", property: "due_date"})).render().el);
            this.$(".due-date-row").append( (new EditableCell({model : this.parent.model, type: "datetime", property: "answer_date"})).render().el);
            this.$(".hwset-visible").html((new EditableCell({model: this.parent.model, property: "visible"})).render().el);
            this.$(".reduced-credit").html((new EditableCell({model: this.parent.model, property: "enable_reduced_scoring"})).render().el);

        }
    });

	var AssignUsersView = Backbone.View.extend({
		tagName: "div",
		initialize: function () {
			_.bindAll(this,'render','selectAll','assignToSelected','updateUserList');
			this.parent = this.options.parent;
		},
		render: function ()  {
			var self = this;
            this.$el.html($("#users-assigned-tmpl").html());

            var allUsers = this.parent.parent.users.sortBy(function(_user) { return _user.get("last_name");});

            this.usersListView = new UserListView({users: allUsers, checked: false, el: this.$("#users-assigned-row")});
            this.updateUserList();
            return this;

		},
        events: { "click #assign-to-selected-users-button": "assignToSelected",
                  "click #classlist-select-all": "selectAll"},
        updateUserList: function () {
            this.usersListView.render();
            this.usersListView.highlightUsers(this.parent.model.assignedUsers);
            this.usersListView.disableCheckboxForUsers(this.parent.model.assignedUsers);
        },
        assignToSelected: function ()
        {
            var selectedUsers = _($("input:checkbox.classlist-li[checked='checked']")).map(function(v){ return $(v).data("username")});
            console.log(selectedUsers)
            console.log("assigning to selected users");

            this.parent.model.assignToUsers(_.difference(selectedUsers,this.parent.model.assignedUsers));
            this.parent.model.assignedUsers = selectedUsers;
        },
        selectAll: function (){
            this.$(".classlist-li").attr("checked",this.$("#classlist-select-all").attr("checked")==="checked");
            _(this.parent.model.assignedUsers).each(function(_user){
                self.$(".classlist-li[data-username='"+ _user + "']").prop("checked",true);
            });
        }

	});

    var CustomizeUserAssignView = Backbone.View.extend({
        tagName: "div",
        initialize: function () {
            _.bindAll(this,'render','selectAll','customizeSelected','unassignUsers');
            this.parent = this.options.parent;
        },


        render: function() {
            this.$el.html($("#custom-assign-tmpl").html());
            this.openDate = new EditableCell({model : this.parent.model, type: "datetime", property: "open_date", silent: true});
            this.dueDate = new EditableCell({model : this.parent.model, type: "datetime", property: "due_date", silent: true});
            this.answerDate = new EditableCell({model : this.parent.model, type: "datetime", property: "answer_date", silent: true});
            this.$(".due-date-row").append(this.openDate.render().el);
            this.$(".due-date-row").append(this.dueDate.render().el);
            this.$(".due-date-row").append(this.answerDate.render().el);

            var allUsers = this.parent.parent.users.sortBy(function(_user) { return _user.get("last_name");});

            this.usersListView = new UserListView({users: allUsers, checked: false, el: this.$("#custom-user-row")}).render();
            this.usersListView.highlightUsers(this.parent.model.assignedUsers);
            return this;
        },
         events: {  "click #custom-save-changes": "customizeSelected",
                    "click #unassign-users": "unassignUsers",
                    "click #custom-select-all": "selectAll"},
        customizeSelected: function ()
        {
            var users = this.usersListView.getSelectedUsers();
            this.parent.model.updateUserSet(users,this.openDate.getValue()+ " " + config.timezone, 
                this.dueDate.getValue()+ " " + config.timezone, this.answerDate.getValue()+ " " + config.timezone);
        },
        selectAll: function (){
            this.usersListView.checkAll(this.$("#custom-select-all").prop("checked"));
        },
        unassignUsers: function(){
            var users = this.usersListView.getSelectedUsers();
            this.parent.model.unassignUsers(users);
            this.parent.model.assignedUsers = _.difference(this.parent.model.assignedUsers,users);

        }
    });

	return HWDetailView;
});