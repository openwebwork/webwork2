define(['backbone','views/SidePane', 'config'],function(Backbone,SidePane,config){
	var LibraryOptionsView = SidePane.extend({
    initialize: function(options){
        this.problemSets = options.problemSets; 
        this.settings = options.settings;
        var LibraryOptions = Backbone.Model.extend({});
        this.model = new LibraryOptions({display_option: this.settings.getSettingValue("pg{options}{displayMode}"),
            target_set: "", new_problem_set: ""});
        _.extend(this,Backbone.Events);
    },
    render: function(){
        this.$el.html($("#library-options-template").html());
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
        ".select-target-option": {observe: "target_set", selectOptions: {
            collection: function () { return this.problemSets.pluck("set_id"); },
            defaultOption: {label: "Select Target...", value: null}
        }},
        ".add-problem-set-option": "new_problem_set"
    },
    events: {
        "change .problem-display-option": function (evt) { this.trigger("change-display-mode", evt);},
        "change .select-target-option": function (evt) {
            if($(evt.target).val()){
                $(".goto-problem-set-button").removeAttr("disabled");
            } else {
                $(".goto-problem-set-button").attr("disabled","disabled");
            }
            this.trigger("change-target-set",evt);},
        "click .add-problem-set-button": function () { this.trigger("add-problem-set",this.model.get("new_problem_set"));},
        "click .show-hide-tags-button" : function (evt) {this.trigger("show-hide-tags",$(evt.target))},
        "click .show-hide-path-button" : function (evt) {this.trigger("show-hide-path",$(evt.target))},
        "click .goto-problem-set-button": function(evt) {
            this.trigger("goto-problem-set",this.$(".select-target-option").val())
        }
    }
});

return LibraryOptionsView;
})