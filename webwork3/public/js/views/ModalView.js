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
            this.modal_size = options.modal_size;
            this.templateOptions = {
                header: options.modal_header, 
                body: options.modal_body, 
                action_button_text: options.modal_action_button_text,
                buttons: options.modal_buttons
            };
            _(this).extend(Backbone.Events);
        },
        parentEvents: {
            "shown.bs.modal": function () { this.trigger("modal-opened");},
            "hidden.bs.modal": function() { this.trigger("modal-closed");}
        },
        childEvents: {},
        events: function (){
            return _({}).extend(this.childEvents,this.parentEvents);
        },
        render: function () {
            var self = this; 
            this.$el.html(this.template(this.templateOptions));
            this.$(".modal-dialog").addClass(this.modal_size)
            this.$(".modal").modal();
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