define(['backbone','views/Sidebar', 'config'],function(Backbone,Sidebar,config){
	var LibraryOptionsView = Sidebar.extend({
    initialize: function(options){
        Sidebar.prototype.initialize.apply(this,[options]);
        var self = this;
        this.problemSets = options.problemSets;
        this.problemSets.on({
            add: this.addProblemSet, sync: function(_set){               
                self.$(".select-target-option").val(_set.get("set_id"));
                self.state.set({new_problem_set: "",target_set: _set.get("set_id")});
                self.trigger("change-target-set",self.state.get("target_set"));
                self.render();
            },
            remove: function(_set){
                self.state.set({target_set: ""});
                self.trigger("change-target-set","");
            }
        }); 
        this.settings = options.settings;

        this.state.set({display_option: this.settings.getSettingValue("pg{options}{displayMode}"),
                target_set: "", new_problem_set: "", show_path: false, show_tags: false},{silent: true})
            .on("change:show_path",function(){
                self.trigger("show-hide-path",self.state.get("show_path"))
            }).on("change:show_tags",function(){
                self.trigger("show-hide-tags",self.state.get("show_tags"));
            });
        this.state.validation = {
            new_problem_set: function(value, attr, computedState) {
                if(_(computedState.problemSets.pluck("set_id")).contains(value)){
                    return "The problem set " + value + " already exists.";
                }
            }
        };

        // put this in Sidebar?
        _.extend(this,Backbone.Events);

    },
    render: function(){
        this.$el.html($("#library-options-template").html());
        this.stickit(this.state,this.bindings);
        if(this.state.get("target_set")){
            this.$(".goto-problem-set-button").removeAttr("disabled");
            this.trigger("change-target-set",this.state.get("target_set"));  
        }

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
        ".add-problem-set-option": "new_problem_set",
        ".show-hide-tags-button": {observe: "show_tags", update: function($el, val, model, options){
            $el.text(val?"Hide Tags":"Show Tags");
        }},
        ".show-hide-path-button": {observe: "show_path", update: function($el, val, model, options){
            $el.text(val?"Hide Path":"Show Path");
        }}

    },
    events: {
        "change .problem-display-option": function (evt) { this.trigger("change-display-mode", evt);},
        "change .select-target-option": function (evt) {
            this.trigger("change-target-set",evt);
            if($(evt.target).val()===""){
                this.$(".goto-problem-set-button").attr("disabled","disabled")
            } else {
                this.$(".goto-problem-set-button").removeAttr("disabled")
            }
        },
        "click .add-problem-set-button": function () { 
            var msg;
            if(msg = this.state.validate()){
                this.$(".add-problem-set-option").popover({title: "Error", content: msg.new_problem_set, placement: "bottom"})
                    .popover("show");
            } else {
                this.$(".add-problem-set-option").popover("destroy");
                this.trigger("add-problem-set",this.state.get("new_problem_set"));
            }
        },
        "click .show-hide-tags-button" : function (evt) {
            this.state.set("show_tags", ! this.state.get("show_tags"));},
        "click .show-hide-path-button" : function (evt) {
            this.state.set("show_path", ! this.state.get("show_path"));},
        "click .goto-problem-set-button": function (){ this.trigger("goto-problem-set",this.state.get("target_set"))}
    },
    addProblemSet: function(_set){
        this.state.set("target_set",_set.get("set_id"));
        this.render();
    }
});


return LibraryOptionsView;
})