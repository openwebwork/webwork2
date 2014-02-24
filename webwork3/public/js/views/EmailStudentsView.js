define(['backbone', 'underscore'], function(Backbone, _){
  EmailStudentsView = Backbone.View.extend({
    tagName: "div",
    className: "emailDialog",
    initialize: function(options) {
       _.bindAll(this,"render"); 
       this.users = options.users;
     },
     render: function ()
     {
          var self = this; 
          this.$el.html(_.template($("#emailStudentTemplate").html(),this.model));
          _(this.users).each(function (user){
            $("#emailStudentList",self.$el).append(user.attributes.first_name + " " + user.attributes.last_name + ","); 
          });
    
    
          this.$el.dialog({autoOpen: false, modal: true, title: config.msgTemplate({type: "password_changes"}),
                          width: (0.75*window.innerWidth), height: (0.75*window.innerHeight),
                          buttons: {"Send Email": function () {self.sendEmail(); self.$el.dialog("close")},
                                    "Cancel": function () {self.$el.dialog("close");}}
                          });
          return this;
     },
     sendEmail: function ()
     {
    
     }
  });
  return EmailStudentsView;
});