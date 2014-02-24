define(['backbone','config'],function(Backbone,config){
	var LibraryOptionsView = Backbone.View.extend({
    initialize: function(options){
        this.problemSets = options.problemSets; 
        var LibraryOptions = Backbone.Model.extend({defaults: {display_option: "",
            target_set: "", new_problem_set: ""}});
        this.model = new LibraryOptions({display_option: "images",
            target_set: "", new_problem_set: "HW2"});
    },
    render: function(){
        this.$el.html($("#library-options-template").html());
        this.stickit();
        return this;
    }, 
    bindings: {".problem-display-option": {observe: "display_option", selectOptions: {
            collection: function () {
                var modes = config.settings.getSettingValue("pg{displayModes}").slice();
                modes.push("None");
                return modes;
            }
        }},
        ".select-target-option": {observe: "target_set", selectOptions: {
            collection: function () { return this.problemSets.pluck("set_id"); },
            defaultOption: {label: "Select Target...", value: null}
        }},
        ".add-problem-set-option": "new_problem_set"}
});

return LibraryOptionsView;
})