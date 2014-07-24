define(['backbone','views/Sidebar', 'config'],function(Backbone,Sidebar,config){
	var ProblemListOptionsSidebar = Sidebar.extend({
    initialize: function(options){
        Sidebar.prototype.initialize.apply(this,[options]);
        this.problemSets = options.problemSets; 
        this.settings = options.settings;
        this.state.set({display_option: this.settings.getSettingValue("pg{options}{displayMode}"),
            target_set: "", new_problem_set: ""},{silent: true});
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
    },
    events: {
        "change .problem-display-option": function (evt) { this.trigger("change-display-mode", evt);},
        "click .show-hide-tags-button" : function (evt) {this.trigger("show-hide-tags",$(evt.target))},
        "click .show-hide-path-button" : function (evt) {this.trigger("show-hide-path",$(evt.target))},
    }
});

return ProblemListOptionsSidebar;
})