define(['backbone','underscore','views/MainView','apps/util'],
    function(Backbone,_,MainView,util){
var UserSettingsView = MainView.extend({
	messageTemplate: _.template($("#user-settings-messages-template").html()),
	initialize: function(options){
		var self = this;
		_(this).bindAll("parseResponse","showError");
		MainView.prototype.initialize.call(this,options);

    this.invBindings = util.getInverseBindings(this.bindings);
	},
  showError: function(opts){
      var el = this.$(this.invBindings[opts.attr]).closest("tr").find(".error-cell");
      util.changeClass({els: el, state: opts.state, remove_class: "bg-danger" });
      el.html(opts.error);
  },
	render: function (){
		this.$el.html($("#user-settings-template").html())
		MainView.prototype.render.apply(this);
		this.changePassword(this.state.get("show_password"));
        util.changeClass({state: this.settings.getSettingValue("pg{specialPGEnvironmentVars}{MathView}"),
                          els: this.$("#equation-editor").closest("tr"), remove_class: "hidden"});
		this.stickit();
        return this;
	},
  set: function(opts){
    var self = this;
    this.model = opts.user_info;
    this.model.on("change:displayMode change:showOldAnswers change:useMathView " +
                  "change:email_address",function(model){
        self.model.save(model.changed);
    }).bind('validated:invalid', function(model, errors) {
       _(errors).chain().keys().each(function(key){
            self.showError({state: false, attr: key, error: errors[key]});
       });
    }).bind('validated:valid', function(model){
        self.$(".error-cell").html("");
        util.changeClass({state: true, els: self.$(".error-cell"), remove_class: "bg-danger"});
    });
    this.stickit();
    return this;

  },
	events: {
		"click #reset-history-button": function () {
      localStorage.removeItem("ww3_cm_state");
      this.appState = {index: 0, states:[this.getState()]};
    },
		"click #change-password-button": function() { this.changePassword(!this.state.get("show_password"));},
		"click #submit-password-button": "submitPassword",
        "keyup #email": function(evt){
            if(evt.keyCode == 13) { $(evt.target).blur();}
        }
	},
	bindings: {
    "#name": {observe: ["first_name","last_name"],
      onGet: function(vals){ return vals[0]+ " " + vals[1]}},
		"#user-id": "user_id",
		"#email": {observe: "email_address", events: ["blur"], setOptions: {validate: true}},
		"#new-password": "new_password",
		"#old-password": "old_password",
		"#confirm-password": "confirm_password",
        "#display-option": {observe: "displayMode", selectOptions: {
            collection: function () {
                return this.settings.getSettingValue("pg{displayModes}").slice();  // makes a copy.
            }
        }},
        "#save-old-answers": "showOldAnswers",
        "#equation-editor": "useMathView"
	},
	submitPassword: function (){
        var error = "";
        if(this.model.get("new_password") !== this.model.get('confirm_password')) {
            this.showError({attr: "confirm_password", error: this.messageTemplate({type: "not_equal_pass"})});
            return;
    	} else if(this.model.get("new_password").length<6){
            this.showError({attr: "confirm_password", error: this.messageTemplate({type: "short_pass"})});
            return;
        }

        this.$(".error-cell").removeClass("bg-danger").html("");
		if(this.model.isValid(true)){
			this.model.savePassword(this.model.pick("new_password","old_password"),{
				success: this.parseResponse});
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
			this.$(".confirm-password").parent().popover("hide");
			this.$(".change-password-button").button("reset");
		}
	},
    parseResponse: function(data){
        if(data.success == 0){
            this.showError({attr: "old_password", error: this.messageTemplate({type: "wrong_pass"})});
            return;
        }
		this.eventDispatcher.trigger("add-message",{type: "success",
                short: this.messageTemplate({type:"password_saved",opts:{user_id: this.model.get("user_id")}}),
                text: this.messageTemplate({type:"password_saved",opts:{user_id: this.model.get("user_id")}})});
        this.$(".old-password").parent().removeClass("has-error");
        this.$(".old-password").popover("hide");
        this.changePassword(false);
    },
	getDefaultState: function () {
		return {show_password: false};
	},
    getHelpTemplate: function () {
        return $("#user-settings-help-template").html();
    }
});


return UserSettingsView;
});
