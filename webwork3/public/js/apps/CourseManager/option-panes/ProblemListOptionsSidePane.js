define(['backbone','views/SidePane', 'config'],function(Backbone,SidePane,config){
	var ProblemListOptionsSidePane = SidePane.extend({
    initialize: function(options){
        SidePane.prototype.initialize.apply(this,[options]);
        this.problemSets = options.problemSets; 
        this.settings = options.settings;
        var LibraryOptions = Backbone.Model.extend({});
        this.model = new LibraryOptions({display_option: this.settings.getSettingValue("pg{options}{displayMode}"),
            target_set: "", new_problem_set: ""});
        _.extend(this,Backbone.Events);
    },
    render: function(){
        this.$el.html($("#problem-list-options-template").html());
        this.stickit();
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

return ProblemListOptionsSidePane;
})