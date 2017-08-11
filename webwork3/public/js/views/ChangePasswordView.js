define(['backbone', 'underscore','config','apps/util','views/ModalView'],
function(Backbone, _, config,util,ModalView){

  var ChangePasswordView = ModalView.extend({
    initialize: function(opts) {
      _(this).extend(_(opts).pick("users","msgTemplate"));
      _(opts).extend({
        modal_size: "modal-lg",
        modal_header: "Change User Passwords", // I18N
        modal_body: $("#change-user-password-template").html(),
        modal_buttons: $("#change-user-password-buttons").html()
      })
      _(this).bindAll("checkResult");
      ModalView.prototype.initialize.apply(this,[opts]);
    },
    render: function(){
      var self = this;
      ModalView.prototype.render.apply(this);
      var table = this.$("#user-password-table tbody");
      this.users.each(function (user) {
            var tableRow = new ChangePasswordRowView({model: user,msgTemplate: self.msgTemplate});
            table.append(tableRow.render().el);
          });
      return this;
    },
    events: {
      "click .action-button": "savePasswords"
    },
    savePasswords: function () {
      var self = this;
      this.password_result = {};
      this.users.each(function(_user){
        self.password_result[_user.get("user_id")] = false;
        _user.savePassword(_user.pick("new_password"),{success:self.checkResult});
      })
    },
    checkResult: function(data){ // if all of the passwords are correct then close.
      this.password_result[data.user_id] = data.success == 1;
      var user = this.users.findWhere({user_id: data.user_id});
      if(user){
          user.unset("new_password",{silent: true});
      }
      if(_(this.password_result).chain().values().all().value()){
        this.close();
      }
    }


});

var ChangePasswordRowView = Backbone.View.extend({
  tagName: "tr",
  initialize: function(opts){
    var self = this;
    this.msgTemplate = opts.msgTemplate;
    if(this.model){
      this.model.on("change:new_password",function(){
        var el = self.$(".new-password");
        util.changeClass({els: el.parent(),
                          state: self.model.get("new_password").length<6,
                          add_class: "has-error" });

        if(self.model.get("new_password").length<6){
            el.popover({content: self.msgTemplate({type: "short_pass"}),
                        trigger: "manual"}).popover("show");
        } else {
          el.popover("hide");
        }
      })
    }

  },
  bindings: {
    ".first-name": "first_name",
    ".last-name": "last_name",
    ".user-id": "user_id",
    ".new-password": {observe: "new_password", events: ["blur"]}
  },
  render: function(){
    this.$el.html($("#change-password-row-template").html());
    this.stickit();
    return this; // for chainable calls, like .render().el
  },
});

return ChangePasswordView;

})
