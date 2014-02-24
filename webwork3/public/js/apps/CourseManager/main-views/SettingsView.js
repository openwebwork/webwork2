define(['backbone','config','views/WWSettingsView'],function(Backbone,config,WWSettingsView){
	var SettingsView = Backbone.View.extend({
    
    initialize: function (options) {
        var self = this;
        _.bindAll(this,'render');

        this.categories = config.settings.chain().pluck("attributes").pluck("category")
            .unique().difference("timezone").value();
     }, 
     events: {
        "shown.bs.tab a[data-toggle='tab']": "changeSettingTab"
     },
     render: function () {
        // get all of the categories except for timezone (include it somewhere?)
        
        $("#settings").html(_.template($("#settings-template").html(),{categories: this.categories}));

        // set up the general settings tab

        $("#setting-tab0").addClass("active");  // show the first settings pane.
        //this.headerView.$("a[href='#setting-tab0']").parent().addClass("active");

        var settings = config.settings.where({category: this.categories[0]});
        this.$(".tab-content .active").empty().append((new WWSettingsView({settings: settings})).render().el);
        this.$('.nav-tabs a:first').tab('show')

     },
     changeSettingTab: function(evt){
        var settings = config.settings.where({category: $(evt.target).text()});
        this.$(".tab-content .active").empty().append((new WWSettingsView({settings: settings})).render().el);

     }
});

return SettingsView;
})