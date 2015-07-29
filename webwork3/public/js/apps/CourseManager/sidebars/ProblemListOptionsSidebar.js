define(['backbone','views/Sidebar', 'config'],function(Backbone,Sidebar,config){
	var ProblemListOptionsSidebar = Sidebar.extend({
    initialize: function(options){
        var self = this;
        Sidebar.prototype.initialize.apply(this,[options]);
        this.problemSets = options.problemSets; 
        this.settings = options.settings;
        this.state.set({display_option: this.settings.getSettingValue("pg{options}{displayMode}"),
            show_path: false, show_tags: false, problem_group: null},{silent: true})
        .on("change:show_path",function(){
            self.trigger("show-hide-path",self.state.get("show_path"))
        }).on("change:show_tags",function(){
            self.trigger("show-hide-tags",self.state.get("show_tags"));
        }).on("change:problem_group", function(){
            if(self.state.get("problem_group")){
                self.trigger("add-prob-from-group", self.state.get("problem_group"));
                self.state.set("problem_group",null);
            }
        });

        _.extend(this,Backbone.Events);
    },
    render: function(){
        this.$el.html($("#problem-list-options-template").html());
        this.stickit(this.state,this.bindings);
        this.stopListening();
        var problems = this.mainView.views.problemsView.problemSetView.deletedProblems; 
        if(problems.length >0) {
            this.$(".undo-delete-button").removeAttr("disabled");
        }
        this.listenTo(problems,"add", function(){
            this.$(".undo-delete-button").removeAttr("disabled");
        }).listenTo(this.mainView.views.problemsView.problemSetView.deletedProblems,"remove", function() {
            if(problems.length == 0 ){
                 this.$(".undo-delete-button").attr("disabled","disabled");
            }
        }); 

        return this;
    }, 
    bindings: {".problem-display-option": {observe: "display_option", selectOptions: {
            collection: function () {
                var modes = this.settings.getSettingValue("pg{displayModes}").slice(); // make a copy of the pg{displayModes}
                modes.push("None");
                return modes;
            }
        }},
        ".show-hide-tags-button": {observe: "show_tags", update: function($el, val, model, options){
            $el.text(val?"Hide Tags":"Show Tags");
        }},
        ".show-hide-path-button": {observe: "show_path", update: function($el, val, model, options){
            $el.text(val?"Hide Path":"Show Path");
        }},
        "select#add-prob-group": {observe: "problem_group", selectOptions: {
            collection: function (){
                return this.problemSets.map(function(_set) { return _set.get("set_id");});
            }, defaultOption: {label: "Add a Problem From a Group", value: null}
        }}
    },
    events: {
        "click .undo-delete-button": function(){
            this.trigger("undo-problem-delete");
        },
        "change .problem-display-option": function (evt) { this.trigger("change-display-mode", evt);},
        "click .show-hide-tags-button" : function (evt) {
            this.state.set("show_tags", ! this.state.get("show_tags"));},
        "click .show-hide-path-button" : function (evt) {
            this.state.set("show_path", ! this.state.get("show_path"));},
            }
});

return ProblemListOptionsSidebar;
})