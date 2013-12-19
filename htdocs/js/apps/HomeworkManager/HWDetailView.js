/**
 *  This is the HWDetailView, which is part of the HomeworkManagmentView.  The view contains the interface to all of the
 *  details of a given homework set including the changing of HWSet properties and assigning of users. 
 *
 *  One must pass a ProblemSet as a model to this.  
 * 
 **/


define(['Backbone', 
    'underscore',
    '../../lib/views/EditableCell',
    '../../lib/views/ProblemListView',
    '../../lib/models/ProblemList',
    '../../lib/views/UserListView','config','bootstrap'], 
    function(Backbone, _,EditableCell,ProblemListView,ProblemList,UserListView,config){
	var HWDetailView = Backbone.View.extend({
        className: "set-detail-view",
        tagName: "div",
        initialize: function () {
            _.bindAll(this,'render','changeHWSet','updateNumProblems');
            this.hwManager = this.options.hwManager;
            this.problemSet = this.model;

            this.problemViewAttrs = {reorderable: true, showPoints: true, showAddTool: false, showEditTool: true,
                    showRefreshTool: true, showViewTool: true, showHideTool: false, deletable: true, draggable: false};

            

            this.views = {
                problemListView : new ProblemListView({headerTemplate: "#problem-set-header", viewAttrs: this.problemViewAttrs}),
                usersAssignedView : new AssignUsersView({hwManager: this.hwManager, problemSet: this.problemSet}),
                propertiesView : new PropertySetDetailView({users: this.hwManager.users, problemSet: this.problemSet}),
                customizeUserAssignView : new CustomizeUserAssignView({hwManager: this.hwManager, parent: this})
            };


            
        },
        render: function () {
            var self = this;
            this.$el.html(_.template($("#HW-detail-template").html()));
            
            this.views.problemListView.displayModes = this.hwManager.settings.getSettingValue("pg{displayModes}");
            this.views.problemListView.setElement($("#problem-list-tab"));
            this.views.usersAssignedView.setElement($("#user-assign-tab"));
            this.views.propertiesView.setElement($("#property-tab"));
            this.views.customizeUserAssignView.setElement($("#user-customize-tab"));       
        },
        events: {"shown a[data-toggle='tab']": "changeView"},
        changeView: function(evt){
            this.views[$(evt.target).data("view")].problemSet = this.problemSet;
            this.views[$(evt.target).data("view")].render();
        },
        changeHWSet: function (setName)
        {
            var self = this;

            $("#problem-set-tabs a:first").tab("show");  // shows the problems tab
        	this.problemSet = this.hwManager.problemSets.find(function(set) {return set.get("set_id")===setName;});
            
            if(this.problemSet.problems){ // have the problems been fetched yet? 
                console.log("changing the HW Set to " + setName);
                this.views.problemListView.setProblems(this.problemSet.problems);
                this.views.problemListView.render();
                this.$(".problem-set-name").html("Problem Set "+ setName);
                this.updateNumProblems();

                this.problemSet.problems.on("add",function (){
                    console.log("Added a Problem");
                    self.hwManager.announce.addMessage({text: "Problem Added to set: " + self.problemSet.get("set_id")});
                });

                // This sets messages 
                this.problemSet.problems.on("deleteProblem",function (setName,place) {
                    var str = "Problem #" + (place +1) + " deleted from set: " + setName + " <br> "
                            + "To undo this, click the Undo button above the problem list. "; 
                    self.hwManager.announce.addMessage({text: str});
                });

                this.problemSet.problems.on("remove",self.updateNumProblems);
                this.problemSet.on("change",function(model)
                {
                    _.chain(model.changed).pairs().each(function(p){
                        self.hwManager.announce.addMessage({text: "The value of " + p[0] + " has changed to " + p[1]});

                    });
                    // need a announcement here.  
                    
                })

                this.problemSet.on("usersAssigned",function(_users,setName){
                    self.hwManager.announce.addMessage({text: "The following users are a assigned to set " + setName + " : " + _users.join(", ")});
                    var view = $("#setDetails .tab-content .active").data("view");
                    self.views[view].render(); 
                });


                this.problemSet.problems.on("num-problems-shown", self.updateNumProblems);
                this.problemSet.on("problem-set-changed", function (set){
                    //self.hwManager.announce.addMessage({text: "Something changed. "});
                });
            
            } else {
                this.problemSet.problems = new ProblemList({type: "Problem Set", setName: setName});
                this.problemSet.problems.on("fetchSuccess",function() {self.changeHWSet(setName)});
            }
        },
        updateNumProblems: function () {
            console.log("firing num-problems-shown");
            var num = this.$("li.problem").size();
            this.$("div.num-probs").html(num + " of " + this.problemSet.problems.size() + " shown");
        }
    });

    var PropertySetDetailView = Backbone.View.extend({
        initialize: function () {
            _.bindAll(this,'render');
            this.problemSet = this.options.problemSet;
            this.users = this.options.users;
        },
        render: function () {
            this.$el.html(_.template($("#hwset-dates-tmpl").html(), 
                {assignedUsers: this.problemSet.assignedUsers.length, numUsers: this.users.length}));
            (new EditableCell({el: this.$(".open-date"), model : this.problemSet, type: "datetime", 
                    property: "open_date"})).render();
            (new EditableCell({el: this.$(".due-date"), model : this.problemSet, type: "datetime", 
                    property: "due_date"})).render();
            (new EditableCell({el: this.$(".answer-date"), model : this.problemSet, type: "datetime", 
                    property: "answer_date"})).render();

            (new EditableCell({el: this.$(".hwset-visible"), model: this.problemSet, property: "visible"})).render();
            (new EditableCell({el: this.$(".reduced-credit"), model: this.problemSet, 
                    property: "enable_reduced_scoring"})).render();

        },
        events: {"click .assign-all-users": "assignAllUsers"},
        assignAllUsers: function(){
            var userNames = this.users.pluck("user_id");
            this.problemSet.assignToUsers(_.difference(userNames,this.problemSet.assignedUsers));
        }
    });

	var AssignUsersView = Backbone.View.extend({
		tagName: "div",
		initialize: function () {
			_.bindAll(this,'render','selectAll','assignToSelected','updateUserList');
			this.hwManager = this.options.hwManager;
            this.problemSet = this.options.problemSet;
		},
		render: function ()  {
			var self = this;
            this.$el.html($("#users-assigned-tmpl").html());

            var allUsers = this.hwManager.users.sortBy(function(_user) { return _user.get("last_name");});

            this.usersListView = new UserListView({users: allUsers, checked: false, el: this.$("#users-assigned-row")});
            this.updateUserList();
            return this;

		},
        events: { "click #assign-to-selected-users-button": "assignToSelected",
                  "click #classlist-select-all": "selectAll"},
        updateUserList: function () {
            this.usersListView.render();
            this.usersListView.highlightUsers(this.problemSet.assignedUsers);
            this.usersListView.disableCheckboxForUsers(this.problemSet.assignedUsers);
        },
        assignToSelected: function ()
        {
            var selectedUsers = _($("input:checkbox.classlist-li[checked='checked']")).map(function(v){ return $(v).data("username")});
            console.log(selectedUsers)
            console.log("assigning to selected users");

            this.problemSet.assignToUsers(_.difference(selectedUsers,this.problemSet.assignedUsers));
        },
        selectAll: function (){
            this.$(".classlist-li").attr("checked",this.$("#classlist-select-all").attr("checked")==="checked");
            _(this.problemSet.assignedUsers).each(function(_user){
                self.$(".classlist-li[data-username='"+ _user + "']").prop("checked",true);
            });
        }

	});

    var CustomizeUserAssignView = Backbone.View.extend({
        tagName: "div",
        initialize: function () {
            _.bindAll(this,'render','selectAll','customizeSelected','unassignUsers');
            this.hwManager = this.options.hwManager;
            this.parent = this.options.parent;
        },


        render: function() {
            this.$el.html($("#custom-assign-tmpl").html());
            this.openDate = new EditableCell({model : this.parent.problemSet, type: "datetime", property: "open_date", silent: true});
            this.dueDate = new EditableCell({model : this.parent.problemSet, type: "datetime", property: "due_date", silent: true});
            this.answerDate = new EditableCell({model : this.parent.problemSet, type: "datetime", property: "answer_date", silent: true});
            this.$(".due-date-row").append(this.openDate.render().el);
            this.$(".due-date-row").append(this.dueDate.render().el);
            this.$(".due-date-row").append(this.answerDate.render().el);

            var allUsers = this.hwManager.users.sortBy(function(_user) { return _user.get("last_name");});

            this.usersListView = new UserListView({users: allUsers, checked: false, el: this.$("#custom-user-row")}).render();
            this.usersListView.highlightUsers(this.parent.problemSet.assignedUsers);
            return this;
        },
         events: {  "click #custom-save-changes": "customizeSelected",
                    "click #unassign-users": "unassignUsers",
                    "click #custom-select-all": "selectAll"},
        customizeSelected: function ()
        {
            var users = this.usersListView.getSelectedUsers();
            this.parent.problemSet.updateUserSet(users,this.openDate.getValue()+ " " + config.timezone, 
                this.dueDate.getValue()+ " " + config.timezone, this.answerDate.getValue()+ " " + config.timezone);
        },
        selectAll: function (){
            this.usersListView.checkAll(this.$("#custom-select-all").prop("checked"));
        },
        unassignUsers: function(){
            var users = this.usersListView.getSelectedUsers();
            this.parent.problemSet.unassignUsers(users);
            this.parent.problemSet.assignedUsers = _.difference(this.parent.problemSet.assignedUsers,users);

        }
    });

	return HWDetailView;
});