/* This View provides the super class for any Settings in WebWork.  The list of Settings should be included by 
    setting the "settings" field and providing it an array of WeBWorKProperty models. 
    */

define(['Backbone', 'underscore','config'], 
function(Backbone, _,config){
    var WWSettingsView = Backbone.View.extend({

        initialize: function (options) {
            _.bindAll(this,'render');
            this.settings = options.settings;
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
                switch(setting.get("type")){
                    case "boolean":
                        var opts = [{label: "true", value: "1"}, {label: "false", value: "0"}];
                        var propHtml = "<select class='select-list'></select>";
                        table.append((new SelectSettingView({model: setting, theOptions: opts,
                                                                 prop_html: propHtml})).render().el);
                        break;
                    case "checkboxlist":
                        var propHtml = "<select multiple='multiple' class='select-list'></select>";
                        var opts = _(setting.get('values')).map(function(opt){ return {label: opt, value: opt}; } );
                        table.append((new SelectSettingView({model: setting, theOptions: opts,
                                                                 prop_html: propHtml})).render().el);
                        break;
                    case "popuplist": 
                        var propHtml = "<select class='select-list'></select>";
                        var opts = _(setting.get('values')).map(function(opt){ return {label: opt, value: opt}; } );
                        table.append((new SelectSettingView({model: setting, theOptions: opts,
                                                                prop_html: propHtml})).render().el);
                        break;
                    case "permission":
                        var propHtml = "<select class='select-list'></select>";
                        // the settings have the labels stored instead of number values for permissions
                        // perhaps we should change this? 
                        var opts = _(config.permissions).map(function(perm){ return {label: perm.label, value: perm.label}});
                        table.append((new SelectSettingView({model: setting, theOptions: opts,
                                                                prop_html: propHtml})).render().el);
                        break;
                    case "text":
                    case "number": 
                        table.append((new TextSettingView({model: setting, 
                                                prop_html: "<input class='property'>"})).render().el);
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
            _.extend(this.bindings,options.bindings);
        },
        render: function () {
            this.$el.html(_.template($("#row-setting-template").html(),this.templateOptions));
            this.stickit();
            return this;
        },
        bindings: { 
            ".doc" : { observe: 'doc',  updateMethod: 'html'},
            ".doc2": { observe: "doc2", updateMethod: "html"}
        },
        events: {
                "click .help-button": "openHelp",
            "click .close": "closeHelp"
        },
        openHelp: function (evt){
            $(evt.target).siblings(".help-hidden").css("display","block");
        },
        closeHelp: function (evt){
            $(evt.target).parent().css("display","none");
        }
    });

    // send the select options in the parameter theOptions

    var SelectSettingView = SettingView.extend({
        initialize: function (options) {
            _.bindAll(this,'render');
            this.theOptions = options.theOptions;
            var theBindings = { ".select-list" : {observe: "value", selectOptions: { collection: "this.theOptions"}}};
            options.bindings = options.bindings? _.extend(options.bindings,theBindings) : theBindings;
            this.constructor.__super__.initialize.apply(this,[options]);
        }
    });

    var TextSettingView = SettingView.extend({
        initialize: function (options) {
            _.bindAll(this,'render');
            var theBindings = { ".property": {observe: "value", events: ['blur']}};
            options.bindings = options.bindings? _.extend(options.bindings,theBindings) : theBindings;
            this.constructor.__super__.initialize.apply(this,[options]);
        },
        events: {"keyup": "checkForEnter"},
        checkForEnter: function(evt){
            if(evt.keyCode == 13){
                $(evt.target).blur();
            }
        }

    });

    return WWSettingsView;
});