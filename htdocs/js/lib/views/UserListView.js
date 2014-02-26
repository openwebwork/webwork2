
define(['Backbone','stickit'], function(Backbone){
    
	var UserListView = Backbone.View.extend({
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

            return this;
		}
	});

	var UserListRowView = Backbone.View.extend({
		tagName: "button",
		className: "btn btn-default",
		initialize: function(options){
			this.template = options.rowTemplate;
		},
		render: function (){
			this.$el.html(this.template.html());
			this.stickit();
			return this;
		},
		bindings: {".user-id": "user_id"}
	})

	return UserListView;

});