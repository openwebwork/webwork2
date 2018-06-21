define(['Backbone', 'underscore'], function(Backbone, _){
  EmailStudentsView = Backbone.View.extend({
    tagName: "div",
    className: "emailDialog",
    initialize: function() { _.bindAll(this,"render"); this.render(); return this;},
     render: function ()
     {
          var self = this; 
          this.$el.html(_.template($("#emailStudentTemplate").html(),this.model));
    this.model.each(function (user){
    $("#emailStudentList",self.$el).append(user.attributes.first_name + " " + user.attributes.last_name + ","); 
      });
    
    
          this.$el.dialog({autoOpen: false, modal: true, title: "Password Changes",
        width: (0.75*window.innerWidth), height: (0.75*window.innerHeight),
                          buttons: {"Send Email": function () {self.sendEmail(); self.$el.dialog("close")},
                                    "Cancel": function () {self.$el.dialog("close");}}
                          });
     },
     sendEmail: function ()
     {
    
     }
  });
  return EmailStudentsView;
});