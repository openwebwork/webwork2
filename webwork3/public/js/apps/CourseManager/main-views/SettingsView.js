/*  This is the main view for the Webwork Settings */


define(['backbone','underscore','config','views/WWSettingsView','views/MainView'],
    function(Backbone,_,config,WWSettingsView,MainView){
var SettingsView = MainView.extend({
    messageTemplate : _.template($("#settings-messages-template").html()),
    initialize: function (options) {
        MainView.prototype.initialize.call(this,options);
        var self = this;
        _.bindAll(this,'render');
        
        this.categories = this.settings.chain().pluck("attributes").pluck("category")
            .unique().difference("timezone").value();
        this.setMessages();
     }, 
     events: {
        "shown.bs.tab a[data-toggle='tab']": "changeSettingTab"
     },
     render: function () {
        this.currentCategory = this.currentCategory || "General";
        // get all of the categories except for timezone (include it somewhere?)
        this.currentCategory = this.currentCategory || this.categories[0];
        MainView.prototype.render.apply(this);
        this.$el.html(_.template($("#settings-template").html(),{categories: this.categories}));
        this.changeSettingTab(this.currentCategory);
        return this;

     },
     changeSettingTab: function(evt){
        this.currentCategory = _.isString(evt)? evt : $(evt.target).text();
        var settings = this.settings.where({category: this.currentCategory});
        var settingNum = this.categories.indexOf(this.currentCategory);
        this.$("#setting-tab"+settingNum).empty().append((new WWSettingsView({settings: settings})).render().el);
        this.$(".settings-tabs li:eq("+settingNum+") a").tab("show")
        this.eventDispatcher.trigger("save-state");
     }, 
     getHelpTemplate: function (){
        return $("#settings-help-template").html();
     },
     getState: function () {
        return {subview: this.currentCategory};
     },
     setState: function(state){
        if(state){
            this.currentCategory = state.subview;
        }
        return this;
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