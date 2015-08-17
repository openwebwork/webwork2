define(['backbone', 'underscore','config','models/Problem','apps/util','imagesloaded','knowl','bootstrap'], 
       function(Backbone, _,config,Problem,util){
    //##The problem View

    //A view defined for the browser app for the webwork Problem model.
    //There's no reason this same view couldn't be used in other pages almost as is.

    /* the view attributes are as follows:
    
        reorderable (boolean): whether the reorder arrow should be shown
        showPoints (boolean): whether the # of points should be shown
        showMaxAttemptes (boolean): whether the maximum number of attempts is shown. 
        showAddTool (boolean): whether the + should be shown to be added to a problemSet
        showEditTool (boolean): whether the edit button should be shown
        showViewTool (boolean): whether the show button should be shown (to be taken to the userSetView )
        showRefreshTool (boolean): whether the refresh button should be shown (for getting a new random problem)
        showHideTool (boolean): whether the hide button (X) should be shown to hide the problem
        deletable (boolean): is the problem deletable from the list its in.       
        draggable (boolean): can the problem be dragged and show the drag arrow (for library problems)
        displayMode (string): the PG display mode for the problem (images, MathJax, none)


        "tags_loaded", "tags_shown", "path_shown",

    */

    var ProblemView = Backbone.View.extend({
        //We want the problem to render in a `li` since it will be included in a list
        tagName:"li",
        className: "problem",
        template: _.template($('#problem-template').html()),
        initialize:function (options) {
            var self = this;
            _.bindAll(this,"render","removeProblem","showPath","showTags");
            _(this).extend(_(options).pick("libraryView","problem_set_view"));
            if(typeof(this.model)==="undefined"){
                this.model = new Problem();
            }

            // the this.state will store information about the state of the problem
            // including whether or not tags or path is shown as well as view attributes
            // which include which tools are shown on a problemView

            this.state = new Backbone.Model(
                _.extend({tags_loaded: false, tags_shown: false, path_shown: false},options.viewAttrs));
            
            this.state.on("change:show_tags",function(){
                    self.showTags(self.state.get("show_tags"));
                }).on("change:show_path",function(){
                    self.showPath(self.state.get("show_path"));
                });

            this.model.on('change:value change:max_attempts change:source_file', function () {
                var isValid = self.model.isValid(_(self.model.changed).keys());
                if(isValid){
                    self.problem_set_view.model.trigger("change:problems",self.problem_set_view.model,self.model);
            }}).on('change:source_file', function(){
                self.model.set("data",""); 
                self.render();
            }); 
           this.invBindings = util.invBindings(this.bindings);
        },

        render:function () {
            var self = this;
            var group_name; 
            if(this.model.get('data') || this.state.get("displayMode")=="None"){
                
                if(this.state.get("displayMode")=="None"){
                    this.model.attributes.data="";
                }

                this.$el.html(this.template(_.extend({},this.model.attributes,this.state.attributes)));
                
                this.$el.imagesLoaded(function() {
                    self.$el.removeAttr("style");
                    self.$(".problem").removeAttr("style");
                    self.$(".loading").remove();
                });


                if (this.state.get("draggable")) {
                    this.$el.draggable({
                        helper:'clone',
                        revert:true,
                        handle:'.drag-handle',
                        appendTo:'body',
                    }); 

                } 

                this.el.id = this.model.cid; // why do we need this? 
                this.$el.attr('data-path', this.model.get('source_file'));
                this.$el.attr('data-id', this.model.get('set_id')+":"+this.model.get("problem_id"));
                this.$el.attr('data-source', this.state.get("type"));
                if (this.state.get("displayMode")==="MathJax"){
                    MathJax.Hub.Queue(["Typeset",MathJax.Hub,this.el]);
                }

                this.showPath(this.state.get("show_path"));
                this.stickit();
                Backbone.Validation.bind(this,{
                    valid: function(view,attr){
                        view.$(self.invBindings[attr]).popover("hide").popover("destroy");
                    },
                    invalid: function(view,attr,error){
                        view.$(self.invBindings[attr]).popover({title: "Error", content: error,container: view.$el}).popover("show");
                    }
                });
                
                 
                // send rendered signal after MathJax 
                if(MathJax){
                    MathJax.Hub.Register.MessageHook("End Math", function (message) { 
                        self.model.trigger("rendered",this);
                        self.state.set("rendered",true);
                    })
                } else {
                    this.model.trigger("rendered",this);
                    this.state.set("rendered",true);
                }
            } else if(group_name = this.model.get("source_file").match(/group:([\w._]+)$/)){
                if(! this.state.get("rendered")){
                    this.model.set("data","This problem is selected from the group: " + group_name[1]);
                    this.render();
                }
            } else {
                this.state.set("rendered",false);
                this.$el.html($("#problem-loading-template").html());
                this.model.loadHTML({displayMode: this.state.get("displayMode"), success: function (data) {
                    self.model.set("data",data.text);
                    self.model.renderData = data;
                    self.render();
                }, error:function(data){
                    self.model.set("data",data.responseText);
                    self.render();
                }});
            }


            return this;
        },
        events: {"click .hide-problem": "hideProblem",
            "click .remove-problem": "removeProblem",
            "click .refresh-problem": 'reloadWithRandomSeed',
            "click .add-problem": "addProblem",
            "click .seed-button": "toggleSeed",
            "click .path-button": function () {this.state.set("show_path",!this.state.get("show_path"))},
            "click .tags-button": function () {this.state.set("show_tags",!this.state.get("show_tags"))},
            "click .mark-correct-btn": "markCorrect",
            "keyup .prob-value,.max-attempts": function (evt){
                if(evt.keyCode == 13){ $(evt.target).blur() }   
            }, 
            "blur .max-attempts": function(evt){
                if($(evt.target).val()==-1){
                    //I18N
                    $(evt.target).val("unlimited");   
                }
            }
        },
        bindings: {
            ".prob-value": {observe: "value", events: ['blur']},
            ".max-attempts": {observe: "max_attempts", events: ['blur'] , onSet: function(val) {
                    return (val=="unlimited")?-1:val;
                }, onGet: function(val){
                    return (val==-1)?"unlimited":val;
                }
            },
            ".mlt-tag": "morelt",
            ".level-tag": "level",
            ".keyword-tag": "keyword",
            ".problem-author-tag": "author",
            ".institution-tag": "institution",
            ".tb-title-tag": "textbook_title",
            ".tb-chapter-tag": "textbook_chapter",
            ".tb-section-tag": "textbook_section",
            ".DBsubject-tag": "subject",
            ".DBchapter-tag": "chapter",
            ".DBsection-tag": "section",
            ".problem-path": {observe: "source_file", events: ["blur"]},
            ".seed": "problem_seed"
        },
        reloadWithRandomSeed: function (){
            var seed = Math.floor((Math.random()*10000));
            console.log("reloading with new seed " + seed);
            this.model.set({data:"", problem_seed: seed});
            this.render();
        },
        showPath: function (_show){
            util.changeClass({els: this.$(".path-row"), state: _show, remove_class: "hidden"});
        },
        showTags: function (_show){
            var self = this;
            if(_show && ! this.state.get("tags_loaded")){
                this.model.loadTags({success: function (){ 
                        self.$(".loading-row").addClass("hidden");
                        self.$(".tag-row").removeClass("hidden");
                        self.state.set('tags_loaded',true);
                    }});
            }
            util.changeClass({els:this.$(".tag-row"),state: _show, remove_class: "hidden"});
        },
        toggleSeed: function () {
            this.$(".problem-seed").toggleClass("hidden");
        },
        markCorrect: function () {
            var conf = confirm(this.problem_set_view.messageTemplate({type:"mark_all_correct"}));
            if(conf){
                this.problem_set_view.markAllCorrect(this.model.get("problem_id"));   
            }
        },
        addProblem: function (evt){
            if(this.libraryView){
                this.libraryView.addProblem(this.model);  
            } else {
                console.error("This is not an addable problem.")
            }
        },
        highlight: function(turn_on){
            if(turn_on){
                this.$(".highlight-problem").removeClass("hidden")
            } else {
                this.$(".highlight-problem").addClass("hidden")
            }
        },
        hideProblem: function(evt){
            this.$el.addClass("hidden");
        },
        removeProblem: function(){
            this.problem_set_view.deleteProblem(this.model); 
            
        }, 
        set: function(opts){
            this.state.set(_(opts).pick("show_path","show_tags","tags_loaded"));
        }
    });

    return ProblemView;
});