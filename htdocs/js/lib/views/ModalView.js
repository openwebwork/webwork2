/**
 *  This is a base class for a Modal View
 * 
 *  in order to use this properly, you must pass a template with the standard modal HTML
 *
 *  Other Paramters 
 *     templatethis.options:  an object containing any this.options needed for the template
 *     modalBodyTemplate:  an html template for the body of the template
 * 	   modalBodyTemplatethis.options: an object containing any this.options need for the modalBodyTemplate
 */  

define(['Backbone','underscore'], function(Backbone, _){

    var ModalView = Backbone.View.extend({
 	  initialize: function () {
            var self = this;
            _.bindAll(this,"render");
            this.template = _.template(this.options.template);
            this.templateOptions = this.options.templateOptions? this.options.templateOptions: {};
            this.buttons = [ { text: "Cancel", click: function() { self.close(); }} ]
            this.buttons.push(this.options.buttons);
            //this.modalBodyTemplate = _.template(this.options.modalBodyTemplate);
            //this.modalBodyTemplateOptions = this.options.modalBodyTemplateOptions? this.options.modalBodyTemplateOptions: {};
        },
        render: function () {
            var self = this; 
            this.$el.html(this.template(this.templateOptions));
            this.$el.dialog({height: 300, width: 400,modal: true,
                buttons: this.buttons, title: this.options.title});
            this.stickit();
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