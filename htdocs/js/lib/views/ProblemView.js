define(['Backbone', 'underscore','config','imagesloaded'
    ], function(Backbone, _,config){
    //##The problem View

    //A view defined for the browser app for the webwork Problem model.
    //There's no reason this same view couldn't be used in other pages almost as is.
    var ProblemView = Backbone.View.extend({
        //We want the problem to render in a `li` since it will be included in a list
        tagName:"li",
        className: "problem",

        //This is the template for a problem, the html is defined in SetMaker3.pm
        template: _.template($('#problem-template').html()),

    
        //In most model views initialize is used to set up listeners
        //on the views model.
        initialize:function () {

            var self = this;
            _.bindAll(this,"render","removeProblem");
            // this.options.viewAttrs will determine which tools are shown on the problem
            this.allAttrs = {};
            _.extend(this.allAttrs,this.options.viewAttrs);

            var probURL = "?effectiveUser=" + config.courseSettings.user + "&editMode=SetMaker&displayMode=" 
                + this.allAttrs.displayMode + "&key=" + config.courseSettings.session_key 
                + "&sourceFilePath=" + this.model.get("source_file") + "&user=" + config.courseSettings.user + "&problemSeed=1234"; 
            _.extend(this.allAttrs,{editUrl: "../pgProblemEditor/Undefined_Set/1/" + probURL, viewUrl: "../../Undefined_Set/1/" + probURL});
            this.model.on('change:value', function () {
                self.model.save();
            });
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


                if (this.options.viewAttrs.draggable) {
                    this.$el.draggable({
                        helper:'clone',
                        revert:true,
                        handle:'.drag-handle',
                        appendTo:'body',
                        //cursorAt:{top:0,left:0}, 
                        //opacity:0.65
                    }); 

                } 

                this.el.id = this.model.cid;
                this.$el.attr('data-path', this.model.get('source_file'));
                this.$el.attr('data-source', this.allAttrs.type);
                if (this.allAttrs.displayMode==="MathJax"){
                    MathJax.Hub.Queue(["Typeset",MathJax.Hub,this.el]);
                }

                this.stickit();
                
            } else {
                this.$el.html("<span style='font: italic 120%'>Loading Problem</span><i class='icon-spinner icon-spin icon-2x'></i>");
                this.model.loadHTML({displayMode: this.allAttrs.displayMode, success: function (data) {
                    if (data.text){
                        self.model.set("data",data.text);
                        self.render();
                    } else {
                        console.log(data);
                    }
                }});
            }


            return this;
        },
        events: {"click .hide-problem": "hideProblem",
            "click .remove-problem": "removeProblem",
            "click .refresh-problem": 'reloadWithRandomSeed',
            "click .add-problem": "addProblem",
            "click .seed-button": "toggleSeed",
            "click .path-button": "togglePath"},
        bindings: {".prob-value": "value"},
        reloadWithRandomSeed: function (){
            var seed = Math.floor((Math.random()*10000));
            console.log("reloading with new seed " + seed);
            this.model.set({data:"", problem_seed: seed},{silent: true});
            this.render();
        },
        toggleSeed: function () {
            this.$(".problem-seed").toggleClass("hidden");
        },
        togglePath: function () {
            this.$(".filename").toggleClass("hidden");
        },
        addProblem: function (evt){
            console.log("adding a problem.");
            this.options.libraryView.addProblem(this.model);  // pstaab: will there be an issue if this is not part of a library?
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