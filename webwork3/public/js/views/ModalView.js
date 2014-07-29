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

define(['backbone','underscore'], function(Backbone, _){

    var ModalView = Backbone.View.extend({
        template: _.template($("#modal-template").html()),
 	    initialize: function (options) {
            var self = this;
            _.bindAll(this,"render");

            this.templateOptions = {header: options.modal_header, body: options.modal_body, 
                save_button_text: options.modal_save_button_text};
            /*this.template = _.template(options.template);
            this.templateOptions = options.templateOptions? options.templateOptions: {};
            this.buttons = [ { text: "Cancel", click: function() { self.close(); }} ]
            if(options.buttons){
                this.buttons.push(options.buttons);
            }*/
            _(this).extend(Backbone.Events);
        },
        events: {
            "shown.bs.modal": function () { this.trigger("modal-opened");},
            "hidden.bs.modal": function() { this.trigger("modal-closed");}
        },
        render: function () {
            var self = this; 
            this.$el.html(this.template(this.templateOptions));
            this.$(".modal").modal();
            /*this.$el.dialog({height: 400, width: 500,modal: true,
                buttons: this.buttons, title: this.title});
            this.$el.siblings(".ui-dialog-buttonpane").children(".ui-dialog-buttonset").addClass("btn-group");
            this.$el.siblings(".ui-dialog-buttonpane").find("button").addClass("btn btn-default");
            if(this.model){
                this.stickit();
            }*/
            return this;
        },
        open: function () {
            this.$(".modal").modal("show");
            
        },
        close: function () {
            this.$(".modal").modal("hide");
        }

 });

 return ModalView;

});