define(['backbone','config','views/WWSettingsView','views/MainView'],function(Backbone,config,WWSettingsView,MainView){
	var SettingsView = MainView.extend({
    
    initialize: function (options) {
        MainView.prototype.initialize.call(this,options);
        var self = this;
        _.bindAll(this,'render');

        this.categories = this.settings.chain().pluck("attributes").pluck("category")
            .unique().difference("timezone").value();
     }, 
     events: {
        "shown.bs.tab a[data-toggle='tab']": "changeSettingTab"
     },
     render: function () {
        // get all of the categories except for timezone (include it somewhere?)
        this.currentCategory = this.currentCategory || this.categories[0];
        this.$el.html(_.template($("#settings-template").html(),{categories: this.categories}));
        var settings = this.settings.where({category: this.currentCategory});
        this.$(".tab-content .active").empty().append((new WWSettingsView({settings: settings})).render().el);
        this.$('.nav-tabs a:eq('+(_(this.categories).indexOf(this.currentCategory)+1)+')').tab('show');
        return this;

     },
     changeSettingTab: function(evt){
        this.currentCategory = $(evt.target).text();
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
            this.currentCategory = state.subview || "General";
        }
        return this;
    }

});

return SettingsView;
})