/* This View provides the super class for any Settings in WebWork.  The list of Settings should be included by 
    setting the "settings" field and providing it an array of WeBWorKProperty models. 
    */

define(['backbone', 'underscore','config'], 
function(Backbone, _,config){
    var WWSettingsView = Backbone.View.extend({

        initialize: function (options) {
            _.bindAll(this,'render');
            this.settings = options.settings;
            this.rowTemplate = _.template($("#row-setting-template").html());

            _(this.settings).each(function(setting){
                setting.on("change", function (model) {
                    model.save();
                });
            });
        },
        render: function ()
        {
            var self = this; 
            this.$el.html($("#settings-table-template").html());
            var table = this.$(".settings-table tbody");
            _(this.settings).each(function(setting){
                var opts, propHTML; 
                switch(setting.get("type")){
                    case "text":
                    case "number": 
                        propHTML = "<input class='property'>";
                        opts = [];
                        break;
                    case "boolean":
                        //opts = [{label: "true", value: true}, {label: "false", value: false}];
                        opts = ["true","false"];
                        propHtml = "<select class='select-list TF-boolean-select'></select>";
                        break;
                    case "checkboxlist":
                        propHtml = "<select multiple='multiple' class='select-list'></select>";
                        opts = _(setting.get('values')).map(function(opt){ return {label: opt, value: opt}; } );
                        break;
                    case "popuplist": 
                        propHtml = "<select class='select-list'></select>";
                        opts = _(setting.get('values')).map(function(opt){ return {label: opt, value: opt}; } );
                        break;
                    case "permission":
                        propHtml = "<select class='select-list'></select>";
                        opts = _(config.permissions).map(function(perm){ return {label: perm.label, value: perm.label}});
                        break;
                }
                switch(setting.get("type")){
                    case "text":
                    case "number": 
                        table.append((new TextSettingView({model: setting, prop_html: propHTML, 
                            rowTemplate: self.rowTemplate})).render().el);
                        break;
                    case "boolean":
                    case "checkboxlist":
                    case "popuplist":
                    case "permission":
                        table.append((new SelectSettingView({model: setting, theOptions: opts,rowTemplate: self.rowTemplate,
                                                                    prop_html: propHtml})).render().el);
                        break;

                }

            });
        return this;
        }
    });

    var SettingView = Backbone.View.extend({
        tagName: "tr",
        initialize: function(options){
            this.templateOptions = _.pick(options,"prop_html");
            this.rowTemplate = options.rowTemplate; 
            _.extend(this.templateOptions,this.model.attributes);
            _.extend(this.bindings,options.bindings);
        },
        render: function () {
            this.$el.html(this.rowTemplate(this.templateOptions));
            this.helpPane = this.$(".help-hidden");
            this.stickit();
            return this;
        },
        bindings: { 
            ".doc" : { observe: 'doc',  updateMethod: 'html'},
            ".doc2": { observe: "doc2", updateMethod: "html"}
        },
        additionalEvents: {
            "click .help-button": "toggleHelp",
            "click .close": "closeHelp"
        },
        events: function () {
            return _.extend({},this.childEvents,this.additionalEvents);
        },  
        toggleHelp: function(){
            if(this.helpPane.css("display")==="none"){
                this.openHelp();
            } else {
                this.closeHelp();
            }
        },
        openHelp: function (){
            this.helpPane.css("display","block");
        },
        closeHelp: function (){
            this.helpPane.css("display","none");
        }
    });

    // send the select options in the parameter theOptions

    var SelectSettingView = SettingView.extend({
        initialize: function (options) {
            //_.bindAll(this,'render');
            this.theOptions = options.theOptions;
            var theBindings = { ".select-list" : {observe: "value", selectOptions: { collection: "this.theOptions"}}};
            options.bindings = options.bindings? _.extend(options.bindings,theBindings) : theBindings;
            SettingView.prototype.initialize.apply(this,[options]);
        }
    });

    var TextSettingView = SettingView.extend({
        initialize: function (options) {
            //_.bindAll(this,'render');
            var theBindings = { ".property": {observe: "value", events: ['blur']}};
            options.bindings = options.bindings? _.extend(options.bindings,theBindings) : theBindings;
            SettingView.prototype.initialize.apply(this,[options]);
        },
        childEvents: {"keyup": "checkForEnter"},
        checkForEnter: function(evt){
            if(evt.keyCode == 13){
                $(evt.target).blur();
            }
        }

    });

    return WWSettingsView;
});