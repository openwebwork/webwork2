/**
 *  This is a base class for a Modal View
 * 
 *  in order to use this properly, you must pass a template with the standard modal HTML
 *
 *  Other Paramters 
 *     templateoptions:  an object containing any options needed for the template
 *     modalBodyTemplate:  an html template for the body of the template
 * 	   modalBodyTemplateoptions: an object containing any options need for the modalBodyTemplate
 */  

define(['Backbone','underscore'], function(Backbone, _){

    var ModalView = Backbone.View.extend({
 	  initialize: function (options) {
            var self = this;
            _.bindAll(this,"render");
            this.template = _.template(options.template);
            this.templateOptions = options.templateOptions? options.templateOptions: {};
            this.buttons = [ { text: "Cancel", click: function() { self.close(); }} ]
            if(options.buttons){
                this.buttons.push(options.buttons);
            }
            this.title = options.title;
        },
        render: function () {
            var self = this; 
            this.$el.html(this.template(this.templateOptions));
            this.$el.dialog({height: 400, width: 500,modal: true,
                buttons: this.buttons, title: this.title});
            this.$el.siblings(".ui-dialog-buttonpane").children(".ui-dialog-buttonset").addClass("btn-group");
            this.$el.siblings(".ui-dialog-buttonpane").find("button").addClass("btn btn-default");
            if(this.model){
                this.stickit();
            }
            return this;
        },
        set: function(opts){
            _(_.keys(opts)).each(function(key){
                this[key]=opts[key];
            });
            return this;
        },
        open: function () {
            this.$el.dialog("open");
            
        },
        close: function () {
            this.$el.dialog("close");
        }

 });

 return ModalView;

});