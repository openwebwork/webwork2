define(['backbone','underscore','views/MainView'],
    function(Backbone,_,MainView){
var UserSettingsView = MainView.extend({
	initialize: function(options){
		MainView.prototype.initialize.call(this,options);
	},
	render: function (){
		this.$el.html($("#user-settings-template").html())
		MainView.prototype.render.apply(this);
		this.stickit(this.user,this.bindings);
        return this;
	},
	events: {
		"click .change-email-button": function() {this.user.set("email_address",$(".email").val());}
	},
	bindings: {
		".user-id": "user_id",
		".email": {observe: "email_address", updateModel: false}
	},
	set: function(options){
		if(options.user_id){
			this.user = this.users.findWhere({user_id: options.user_id});
		}
	},
	getDefaultState: function () {
		return {};
	}
});

return UserSettingsView;
});