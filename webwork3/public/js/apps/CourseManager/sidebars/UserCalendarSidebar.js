
define(['backbone','views/Sidebar','stickit'], function(Backbone,Sidebar){
    
	var UserListView = Sidebar.extend({
		template: _.template($("#user-template").html()),
		initialize: function(options) {
			var self = this;
			_(this).bindAll("filterUsers");
			Sidebar.prototype.initialize.apply(this,[options]);
			this.userInfoList =  new UserInfoList(options.users.map(function(_u){
				return _(_u.attributes).pick("last_name","first_name","user_id");
			}));
			this.collection = this.userInfoList; 
			this.userCalendars = {};

			this.collection.on("change:selected_for_calendar",function(model){
				self.state.set("selected_users",self.collection.chain()
						.filter(function(_u) { return _u.get("selected_for_calendar");})
						.pluck("attributes").pluck("user_id").value());
				self.trigger("selected-users-changed",self.state.get("selected_users"));
			})
			this.state.set({filter_text:"",selected_users:[]},{silent:true});
			this.state.on("change:filter_text",this.filterUsers);
		},
		rowTemplate: $("#user-calendar-list-template"),
		render: function () {
			var self = this;
			this.$el.html($("#user-calendar-template").html());
			this.$(".user-calendar-help-button").button();
			_(this.state.get("selected_users")).each(function(_user){
				self.collection.findWhere({user_id: _user}).set("selected_for_calendar",true);
			});

			this.buildUserList();
			Sidebar.prototype.render.apply(this);
			this.stickit(this.state,this.bindings);
            return this;
		},
		buildUserList: function () {
			var ul = this.$(".user-calendar-list")
				, self = this;
			ul.empty();
			this.collection.each(function(user){
				ul.append(new UserListRowView({model:user,rowTemplate: self.rowTemplate}).render().el);
			});
			this.$(".user-calendar").append(ul);
		},
		events: {
			"click .user-calendar-help-button": "showHideHelp",
			"click .user-calendar-eraser-button": function () {
				this.state.set("filter_text","");
			}
		},
		bindings: {
			".user-calendar-filter": "filter_text"
		},
		filterUsers: function(evt){
			var filterStr = this.state.get("filter_text");
			if(filterStr===""){
				this.collection = this.userInfoList;
			} else {
				filterRE = new RegExp(filterStr,"i");
				this.collection =  new UserInfoList(this.userInfoList.filter(function(model){
					return _(model.attributes).values().join(";").search(filterRE) > -1;
				}));
			}
			this.buildUserList();
		},
		showHideHelp: function(evt){
			var button = $(evt.target);
			if(this.$(".user-calendar-help").hasClass("hidden")){
				this.$(".user-calendar-help").removeClass("hidden");
			} else {
				this.$(".user-calendar-help").addClass("hidden");
			}
		}
	});

	var UserListRowView = Backbone.View.extend({
		tagName: "li",
		className: "checkbox",
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