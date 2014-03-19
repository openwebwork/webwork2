define(['backbone','config','views/WWSettingsView','views/MainView'],function(Backbone,config,WWSettingsView,MainView){
	var SettingsView = MainView.extend({
    
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
        this.$el.html(_.template($("#settings-template").html(),{categories: this.categories}));
        this.changeSettingTab(this.currentCategory);
        this.$(".settings-tabs a[href='#setting-tab"+_(this.categories).indexOf(this.currentCategory)+"']").tab("show");
        return this;

     },
     changeSettingTab: function(evt){
        this.currentCategory = _.isString(evt)? evt : $(evt.target).text();
        var settings = this.settings.where({category: this.currentCategory});
        this.$(".tab-content .active").empty().append((new WWSettingsView({settings: settings})).render().el);
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
                    self.eventDispatcher.trigger("add-message",{type: "success",
                        short: config.msgTemplate({type:"setting_saved",opts:{varname:setting.get("var")}}), 
                        text: config.msgTemplate({type:"setting_saved_details"
                                ,opts:{varname:setting.get("var"), oldValue: setting.changingAttributes[key],
                                    newValue: setting.get("value") }})}); 
                });
            }
        }); 
    }
});

return SettingsView;
})