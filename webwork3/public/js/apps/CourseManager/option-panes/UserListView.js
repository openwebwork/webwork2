
define(['backbone','views/SidePane','stickit'], function(Backbone,SidePane){
    
	var UserListView = SidePane.extend({
		template: _.template($("#user-template").html()),
		initialize: function(options) {
			this.users = options.users;
		},
		rowTemplate: $("#user-list-row-template"),
		render: function () {
			var self = this;
			this.$el.html($("#user-list-template").html());
			var ul = this.$(".btn-group-vertical");
			this.users.each(function(user){
				ul.append(new UserListRowView({model:user,rowTemplate: self.rowTemplate}).render().el);
			});

			if(ul.width()>this.$el.width()){
				ul.width(this.$el.width());
			}
			SidePane.prototype.render.apply(this);
            return this;
		}
	});

	var UserListRowView = Backbone.View.extend({
		tagName: "button",
		className: "btn btn-default user-button",
		initialize: function(options){
			this.template = options.rowTemplate;
		},
		render: function (){
			this.$el.html(this.template.html());
			this.$el.data("userid",this.model.get("user_id"));
			this.stickit();
			return this;
		},
		bindings: {".user-id": "user_id", ".first-name": "first_name", ".last-name": "last_name"},
		events: {"click": "actAsUser"},
		actAsUser: function(){
			this.model.collection.trigger("act_as_user",this.model);
		}
	})

	return UserListView;

});