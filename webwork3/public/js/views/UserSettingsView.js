define(['backbone','underscore','views/MainView'],
    function(Backbone,_,MainView){
var UserSettingsView = MainView.extend({
	messageTemplate: _.template($("#user-settings-messages-template").html()),
	initialize: function(options){
		var self = this;
		_(this).bindAll("saveSuccess","saveError");
		MainView.prototype.initialize.call(this,options);
		this.model = new UserPasswordModel();
		this.model.bind('validated:invalid', function(model, errors) {
		 	self.$(".confirm-password").parent().addClass("has-error");
		 	self.$(".confirm-password").popover({title: "Error", content: errors.new_password}).popover("show");
		}).bind('validated:valid',function(model) {
			self.$(".confirm-password").parent().removeClass("has-error");
			self.$(".confirm-password").popover("hide");
		}).on("change:displayMode change:showOldAnswers",function(model){
            self.user.set(model.changed);
        });
      
	},
	render: function (){
		this.$el.html($("#user-settings-template").html())
		MainView.prototype.render.apply(this);
		this.changePassword(this.state.get("show_password"));
		this.stickit();
        return this;
	},
	events: {
		"blur .email": function() {this.user.set("email_address",$(".email").val());},
		"click .reset-history-button": function () { localStorage.removeItem("ww3_cm_state");},
		"click .change-password-button": function() { this.changePassword(!this.state.get("show_password"));},
		"click .submit-password-button": "submitPassword"
	},
	bindings: {
		".user-id": "user_id",
		".email": {observe: "email_address", updateModel: false},
		".new-password": "new_password",
		".old-password": "old_password",
		".confirm-password": "confirm_password",
        ".display-option": {observe: "displayMode", selectOptions: {
            collection: function () {
                return this.settings.getSettingValue("pg{displayModes}").slice();  // makes a copy. 
            }
        }},
        ".save-old-answers": "showOldAnswers"

	},
	submitPassword: function (){
		if(this.model.isValid(true)){
			this.user.savePassword(this.model.pick("new_password","old_password"),{
				success: this.saveSuccess, error: this.saveError});
		}
	},
	changePassword: function (_show){
		this.state.set("show_password",_show);
		if(_show){
			this.$(".password-row").removeClass("hidden");	
			this.$(".change-password-button").button("hide");
		} else {
			this.$(".password-row").addClass("hidden");
			this.model.set({old_password:"",new_password:"",confirm_password:""});
			this.$(".confirm-password").popover("hide");
			this.$(".change-password-button").button("reset");
		}	
	},
    saveSuccess: function(data){
		this.eventDispatcher.trigger("add-message",{type: "success", 
                short: this.messageTemplate({type:"password_saved",opts:{user_id: this.user.get("user_id")}}),
                text: this.messageTemplate({type:"password_saved",opts:{user_id: this.user.get("user_id")}})});
        this.$(".old-password").parent().removeClass("has-error");
        this.$(".old-password").popover("hide");
        this.changePassword(false);
    },
    saveError: function (response) {
        this.$(".old-password").parent().addClass("has-error");
        this.$(".old-password").popover({content: response.responseJSON.error}).popover("show");
    },
	set: function(options){
		if(options.user_id){
			this.user = this.users.findWhere({user_id: options.user_id});
			this.model.set(this.user.attributes);
          
            this.user.on("change",function(_u){
              console.log(_u.attributes);
            });

		}
	},
	getDefaultState: function () {
		return {show_password: false};
	},
    getHelpTemplate: function () {
        return $("#user-settings-help-template").html();
    }
});

var UserPasswordModel = Backbone.Model.extend({
	defaults: {
		user_id: "",
		old_password: "",
		new_password: "",
		confirm_password: "",
        displayMode: "",
        showOldAnswers: true
	},
	validation: {
    	new_password: 'validatePassword',
    	confirm_password: 'validatePassword'
  	},
  	validatePassword: function(value, attr, computedState) {
    	if(this.get("new_password") !== this.get('confirm_password')) {
      		return 'The confirmed password is not equal to the new password'; // #I18N
    	}
  	}
});

return UserSettingsView;
});