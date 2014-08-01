define(['backbone','views/Sidebar', 'config'],function(Backbone,Sidebar,config){
	var ProblemListOptionsSidebar = Sidebar.extend({
    initialize: function(options){
        var self = this;
        Sidebar.prototype.initialize.apply(this,[options]);
        this.problemSets = options.problemSets; 
        this.settings = options.settings;
        this.state.set({display_option: this.settings.getSettingValue("pg{options}{displayMode}"),
            show_path: false, show_tags: false},{silent: true})
        .on("change:show_path",function(){
            self.trigger("show-hide-path",self.state.get("show_path"))
        }).on("change:show_tags",function(){
            self.trigger("show-hide-tags",self.state.get("show_tags"));
        });

        _.extend(this,Backbone.Events);
    },
    render: function(){
        this.$el.html($("#problem-list-options-template").html());
        this.stickit(this.state,this.bindings);
        return this;
    }, 
    bindings: {".problem-display-option": {observe: "display_option", selectOptions: {
            collection: function () {
                var modes = this.settings.getSettingValue("pg{displayModes}").slice();
                modes.push("None");
                return modes;
            }
        }},
        ".show-hide-tags-button": {observe: "show_tags", update: function($el, val, model, options){
            $el.text(val?"Hide Tags":"Show Tags");
        }},
        ".show-hide-path-button": {observe: "show_path", update: function($el, val, model, options){
            $el.text(val?"Hide Path":"Show Path");
        }}

    },
    events: {
        "change .problem-display-option": function (evt) { this.trigger("change-display-mode", evt);},
        "click .show-hide-tags-button" : function (evt) {
            this.state.set("show_tags", ! this.state.get("show_tags"));},
        "click .show-hide-path-button" : function (evt) {
            this.state.set("show_path", ! this.state.get("show_path"));},
            }
});

return ProblemListOptionsSidebar;
})