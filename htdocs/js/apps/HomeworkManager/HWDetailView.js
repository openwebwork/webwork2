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
            _.bindAll(this,'render','changeHWSet','renderProblems');
            this.parent = this.options.parent;
            this.dispatcher = _.clone(Backbone.Events);
            this.render();

        },
        changeHWSet: function (setName)
        {
            var self = this;

            $("#problem-set-tabs a:first").tab("show");
            //$(".view-header[data-view='problem-set']").html("Problem Set Details for " + setName);
            // this.model will be a ProblemSet 
        	this.model = this.collection.find(function(model) {return model.get("set_id")===""+setName;});
            
            if(this.model.problems){
                console.log("changing the HW Set to " + setName);
                this.renderProblems();
                this.model.problems.on("add",function (set){
                    console.log("Added a Problem");
                    self.parent.announce.appendHTML("Problem Added to set: " + set.get("set_id"));
                });
                //this.render();
            } else {
                this.model.problems = new ProblemList({type: "Problem Set", setName: setName});
                this.model.problems.on("fetchSuccess",function() {self.changeHWSet(setName)});
            }


            // This sets messages 
            this.model.on("deleteProblem",function (setName,place) {
                var str = "Problem #" + (place +1) + " Deleted from set: " + setName + " <br> "
                        + "To undo this, click the Undo button above the problem list. "; 
                self.parent.announce.appendHTML(str);
            });
            
            this.dispatcher.off("num-problems-shown");
        	this.dispatcher.on("num-problems-shown", function(num){
                console.log("firing num-problems-shown");
                self.$("div.num-probs").html(num + " of " + self.model.problems.size() + " shown");
            });
        },
        render: function () {
            var self = this;
            this.$el.html(_.template($("#HW-detail-template").html()));
            // activate the tabs
            $('#problem-set-tabs a').click(function (e) {
                e.preventDefault();
                $(this).tab('show');
            });

            //_(this.model.attributes).each(function(value,key) { 
            //	$("#detail-table").append((new HWDetailRowView({model: self.model, property: key})).el)
            //});
/*
            $("#dates-for-hw-set").html(_.template($("#hwset-dates-tmpl").html()));
            $("#due-date-row").append( (new EditableCell({model : this.model, property: "open_date"})).render().el);
            $("#due-date-row").append( (new EditableCell({model : this.model, property: "due_date"})).render().el);
            $("#due-date-row").append( (new EditableCell({model : this.model, property: "answer_date"})).render().el);

            $("div#accord-HW-detail a[href='#collapseOne']").text("Homework Set: " +this.model.get("set_id"));
            $("#usersLabel").text("Assign the set " +this.model.get("set_id") + " to the following");

            this.model.countSetUsers();
			$("#openUserDialog").width("75%").css("left","37.5%");
         
            this.model.on("countUsers",function(selectedUserIds){
                console.log("in countUsers");
                $("#num-users-assigned").html(selectedUserIds.length + " of " + self.parent.users.length);
				$("#byName").html((new SelectedUsersView({users: self.parent.users, selectedUsers: selectedUserIds})).el);
				$('#assignUsersTab a').click(function (e) {
					e.preventDefault();
					$(this).tab('show');
				})


            });

            $("#assignUsersButton").click(function() {console.log("assigning to users");
                $("#openUserDialog").modal('hide');
            });


            $('#problems').on('show',self.renderProblems);
*/
            return this;
       
    	},
        renderProblems: function (){
            console.log("showing the problems for problem set " + this.model.get("set_id"));
            $("#prob-tab").html(_.template($("#problem-set-header").html(),{set: this.model.get("set_id")}));
            var plv = new ProblemListView({el: this.$(".prob-list"), parent: this, collection: this.model.problems,
                                        reorderable: true, deletable: true, draggable: false});
            plv.render();
        }
    });

	var SelectedUsersView = Backbone.View.extend({
		tagName: "div",
		initialize: function () {
			_.bindAll(this,'render');
			_.extend(this,this.options);
			this.render();
		},
		render: function ()  {
			var self = this;
			this.$el.html(_.template($("#selectedUsersHelp").html()));
			this.$el.append("<ul id='classlist'></ul>");
			var cl = this.$("#classlist");
			this.users.each(function(user) { 
				if (_(self.selectedUsers).contains(user.get("user_id")))
				{
				 cl.append("<li><input checked='checked' type='checkbox' id='li-" + user.cid +"'>" 
                    + user.get("first_name") + " " + user.get("last_name") + "</li>");
				} else
				{
				 cl.append("<li style='color: blue'><input type='checkbox' id='li-" + user.cid +"'>" 
                    + user.get("first_name") + " " + user.get("last_name") + "</li>");
				}
            });



		}

	});

	return HWDetailView;
});