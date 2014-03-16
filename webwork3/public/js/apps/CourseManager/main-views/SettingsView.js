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
        this.$el.html(_.template($("#settings-template").html(),{categories: this.categories}));
        var settings = this.settings.where({category: this.categories[0]});
        this.$(".tab-content .active").empty().append((new WWSettingsView({settings: settings})).render().el);
        this.$('.nav-tabs a:first').tab('show');
        return this;

     },
     changeSettingTab: function(evt){
        var settings = this.settings.where({category: $(evt.target).text()});
        this.$(".tab-content .active").empty().append((new WWSettingsView({settings: settings})).render().el);

     }, 
     getHelpTemplate: function (){
        return $("#settings-help-template").html();
     }
});

return SettingsView;
})