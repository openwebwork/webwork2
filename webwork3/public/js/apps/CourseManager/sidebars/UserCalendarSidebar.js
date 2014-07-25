
define(['backbone','views/Sidebar','stickit'], function(Backbone,Sidebar){
    
	var UserListView = Sidebar.extend({
		template: _.template($("#user-template").html()),
		initialize: function(options) {
			var self = this;
			Sidebar.prototype.initialize.apply(this,[options]);
			this.collection = new UserInfoList(options.users.map(function(_u){
				return _(_u.attributes).pick("last_name","first_name","user_id");
			}));
			this.userCalendars = {};

			this.collection.on("change:selected_for_calendar",function(model){
				self.trigger("selected-users-changed", self.collection.chain()
						.filter(function(_u) { return _u.get("selected_for_calendar");})
						.pluck("attributes").pluck("user_id").value());
			})
/*			this.on("selected-users-changed",function(model){
				console.log(model);
			});*/
		},
		rowTemplate: $("#user-calendar-list-template"),
		render: function () {
			var self = this;
			this.$el.html($("#user-calendar-template").html());
			var ul = $("<ul>").addClass('no-bullets')
			this.collection.each(function(user){
				ul.append(new UserListRowView({model:user,rowTemplate: self.rowTemplate}).render().el);
			});
			this.$(".user-calendar").append(ul);

			if(ul.width()>this.$el.width()){
				ul.width(this.$el.width());
			}
			Sidebar.prototype.render.apply(this);
            return this;
		}
	});

	var UserListRowView = Backbone.View.extend({
		tagName: "li",
		initialize: function(options){
			this.template = options.rowTemplate;
		},
		render: function (){
			this.$el.html(this.template.html());
			this.$el.data("userid",this.model.get("user_id"));
			this.stickit();
			return this;
		},
		bindings: {
			".user-id": "user_id", 
			".first-name": "first_name", 
			".last-name": "last_name",
			".user-calendar-checkbox": "selected_for_calendar"
		},
	})

	var UserInfo = Backbone.Model.extend({
		defaults: {
			first_name: "",
			last_name: "",
			user_id: "",
			selected_for_calendar: false
		}
	});

	var UserInfoList = Backbone.Collection.extend({
		model: UserInfo,
		comparator: 'last_name'
	})

	return UserListView;

});