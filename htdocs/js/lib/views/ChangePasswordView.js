define(['Backbone', 'underscore','config'], 
  function(Backbone, _, config){

  var ChangePasswordView = Backbone.View.extend({
      tagName: "div",
      className: "passwordDialog",
      initialize: function() {
         _.bindAll(this,"render");  return this;
         this.users = options.users;
      },
       render: function ()
       {
          var self = this; 
          this.$el.html(_.template($("#passwordDialogText").html(),this.model));
          _(this.users).each(function (user) {
              var tableRow = new ChangePasswordRowView({model: user});
              $("table tbody",self.$el).append(tableRow.el);
          });
          
          this.$el.dialog({autoOpen: false, modal: true, title: config.msgTemplate({type: "password_changes"}),
  			                    width: (0.5*window.innerWidth), height: (0.5*window.innerHeight),
                            buttons: {"Save New Passwords": function () {self.savePasswords(); self.$el.dialog("close")},
                                    "Cancel": function () {self.$el.dialog("close");}}
                          });
          return this;
     },
     savePasswords: function () {
          _(this.users).each(function(user) {user.save();});
     }
     
     
  });

  var ChangePasswordRowView = Backbone.View.extend({
    tagName: "tr",
    className: "CPuserRow",
    initialize: function(){
        _.bindAll(this, 'render','updatePassword'); // every function that uses 'this' as the current object should be in here
        this.render();
              return this;
    },
    events: {
        'change input': 'updatePassword'
    },
    bindings: {".first-name": "first_name",
                ".last-name": "last_name",
                ".user-id": "user_id",
                ".new-password": "new_password"},
    render: function(){
        this.$el.html($("#change-password-row-template").html());
        this.stickit();
        return this; // for chainable calls, like .render().el
    },
    updatePassword: function(evt){  
        var changedAttr = evt.target.className.split("for-")[1];
        this.model.set("new_password",evt.target.value, {silent: true}); // so a server hit is not made at this moment.  
        console.log("new password: " + evt.target.value);
    }
    });

  return ChangePasswordView;

})