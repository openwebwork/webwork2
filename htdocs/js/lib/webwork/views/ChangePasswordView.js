define(['Backbone', 'underscore', './ChangePasswordRowView'], function(Backbone, underscore, ChangePasswordRowView){

  ChangePasswordView = Backbone.View.extend({
      tagName: "div",
      className: "passwordDialog",
      initialize: function() { _.bindAll(this,"render"); this.render(); return this;},
     render: function ()
     {
          var self = this; 
          this.$el.html(_.template($("#passwordDialogText").html(),this.model));
          this.model.each(function (user) {
              var tableRow = new ChangePasswordRowView({model: user});
              $("table tbody",self.$el).append(tableRow.el);
          });
          
          this.$el.dialog({autoOpen: false, modal: true, title: "Password Changes",
  			width: (0.5*window.innerWidth), height: (0.5*window.innerHeight),
                          buttons: {"Save New Passwords": function () {self.savePasswords(); self.$el.dialog("close")},
                                    "Cancel": function () {self.$el.dialog("close");}}
                          });
     },
     savePasswords: function () {
          this.model.each(function(user) {user.change();});
     }
     
     
  });
  return ChangePasswordView;

})