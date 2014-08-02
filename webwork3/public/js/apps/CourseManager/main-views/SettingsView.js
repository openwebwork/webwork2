/*  This is the main view for the Webwork Settings */


define(['backbone','underscore','config','views/WWSettingsView','views/MainView'],
    function(Backbone,_,config,WWSettingsView,MainView){
var SettingsView = MainView.extend({
    messageTemplate : _.template($("#settings-messages-template").html()),
    initialize: function (options) {
        this.categories = options.settings.chain().pluck("attributes").pluck("category")
            .unique().difference("timezone").value();

        MainView.prototype.initialize.call(this,options);


        this.setMessages();
     }, 
     events: {
        "shown.bs.tab a[data-toggle='tab']": "changeSettingTab"
     },
     render: function () {
        this.$el.html(_.template($("#settings-template").html(),{categories: this.categories}));
        this.changeSettingTab(this.state.get("category"));
        MainView.prototype.render.apply(this);
        return this;

     },
     getDefaultState: function () {
        return {category: this.categories[0]};
     },
     changeSettingTab: function(evt){
        this.state.set("category",_.isString(evt)? evt : $(evt.target).text());
        var settings = this.settings.where({category: this.state.get("category")});
        var settingNum = this.categories.indexOf(this.state.get("category"));
        this.$("#setting-tab"+settingNum).empty().append((new WWSettingsView({settings: settings})).render().el);
        this.$(".settings-tabs li:eq("+settingNum+") a").tab("show")
        this.eventDispatcher.trigger("save-state");
     }, 
     getHelpTemplate: function (){
        return $("#settings-help-template").html();
     },
     setMessages: function () {
        var self = this; 
                /* Set the events for the settings */
        this.settings.on({
            change: function(setting){
                setting.changingAttributes=_.pick(setting._previousAttributes,_.keys(setting.changed));
            },
            sync: function(setting){
                _(_.keys(setting.changingAttributes)).each(function(key){
                    var msg = setting.get("doc").replace(/\(.*\)/,"");
                    self.eventDispatcher.trigger("add-message",{type: "success",
                        short: self.messageTemplate({type:"setting_saved",opts:{varname:msg}}), 
                        text: self.messageTemplate({type:"setting_saved_details"
                                ,opts:{varname:setting.get("var"), oldValue: setting.changingAttributes[key],
                                    newValue: setting.get("value") }})}); 
                });
            }
        }); 
    }
});

return SettingsView;
})