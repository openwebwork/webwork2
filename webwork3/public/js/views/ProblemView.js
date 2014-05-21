define(['backbone', 'underscore','config','models/Problem','imagesloaded','knowl'
    ], function(Backbone, _,config,Problem){
    //##The problem View

    //A view defined for the browser app for the webwork Problem model.
    //There's no reason this same view couldn't be used in other pages almost as is.
    var ProblemView = Backbone.View.extend({
        //We want the problem to render in a `li` since it will be included in a list
        tagName:"li",
        className: "problem",
        //This is the template for a problem, the html is defined in SetMaker3.pm
        template: _.template($('#problem-template').html()),
        initialize:function (options) {
            var self = this;
            _.bindAll(this,"render","removeProblem");
            this.libraryView = options.libraryView;
            if(typeof(this.model)==="undefined"){
                this.model = new Problem();
            }
            // options.viewAttrs will determine which tools are shown on the problem
            this.allAttrs = {};
            _.extend(this.allAttrs,options.viewAttrs);
                        
            this.model.on('change:value', function () {
                if(self.model.get("value").match(/^\d+$/)) {
                    self.model.save();
                }
            });
            this.tagsLoaded=false;
            this.rendered = false;
        },

        render:function () {
            var self = this;
            if(this.model.get('data') || this.allAttrs.displayMode=="None"){
                _.extend(this.allAttrs,this.model.attributes);
                if(this.allAttrs.displayMode=="None"){
                    this.model.attributes.data="";
                }
                this.$el.html(this.template(this.allAttrs));
                
                this.$el.imagesLoaded(function() {
                    self.$el.removeAttr("style");
                    self.$(".problem").removeAttr("style");
                    self.$(".loading").remove();
                });


                if (this.allAttrs.draggable) {
                    this.$el.draggable({
                        helper:'clone',
                        revert:true,
                        handle:'.drag-handle',
                        appendTo:'body',
                        //cursorAt:{top:0,left:0}, 
                        //opacity:0.65
                    }); 

                } 

                this.el.id = this.model.cid; // why do we need this? 
                this.$el.attr('data-path', this.model.get('source_file'));
                this.$el.attr('data-source', this.allAttrs.type);
                if (this.allAttrs.displayMode==="MathJax"){
                    MathJax.Hub.Queue(["Typeset",MathJax.Hub,this.el]);
                }

                this.stickit();
                this.model.trigger("rendered",this);
                this.rendered = true;
                
            } else {
                this.rendered = false;
                this.$el.html($("#problem-loading-template").html());
                this.model.loadHTML({displayMode: this.allAttrs.displayMode, success: function (data) {
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
            "click .path-button": "togglePath",
            "click .tags-button": "toggleTags"
        },
        bindings: {".prob-value": "value",
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
        },
        reloadWithRandomSeed: function (){
            var seed = Math.floor((Math.random()*10000));
            console.log("reloading with new seed " + seed);
            this.model.set({data:"", problem_seed: seed},{silent: true});
            this.render();
        },
        toggleTags: function () {
            this.$(".problem-tags").toggleClass("hidden");
        },
        toggleSeed: function () {
            this.$(".problem-seed").toggleClass("hidden");
        },
        togglePath: function () {
            this.$(".filename").toggleClass("hidden");
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
            console.log("hiding a problem ");
            this.$el.css("display","none")
        },
        removeProblem: function(){
            console.log("removing problem");
            //this.model.collection.remove(this.model);
            this.model.collection.remove(this.model);
            this.remove();  // remove the view
        }
    });

    return ProblemView;
});