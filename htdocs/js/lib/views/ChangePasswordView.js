define(['Backbone', 'underscore'], 
  function(Backbone, underscore){

  var ChangePasswordView = Backbone.View.extend({
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
    render: function(){
              this.$el.html("<td> " + this.model.attributes.first_name + "</td><td>" + this.model.attributes.last_name + "</td><td>"
                            + this.model.attributes.user_id +" </td><td><input type='text' size='10' class='newPass'></input></td>");

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