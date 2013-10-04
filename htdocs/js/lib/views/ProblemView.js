define(['Backbone', 'underscore','config','imagesloaded'
    ], function(Backbone, _,config){
	//##The problem View

    //A view defined for the browser app for the webwork Problem model.
    //There's no reason this same view couldn't be used in other pages almost as is.
    var ProblemView = Backbone.View.extend({
        //We want the problem to render in a `li` since it will be included in a list
        tagName:"li",
        className: "problem",
        //Add the 'problem' class to every problem
        //className: "problem",
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

            var probURL = "?effectiveUser=" + config.courseSettings.user + "&editMode=SetMaker&displayMode=images&key=" 
                + config.courseSettings.session_key 
                + "&sourceFilePath=" + this.model.get("source_file") + "&user=" + config.courseSettings.user + "&problemSeed=1234"; 
            _.extend(this.allAttrs,{editUrl: "../pgProblemEditor/Undefined_Set/1/" + probURL, viewUrl: "../../Undefined_Set/1/" + probURL});
            //this.model.on('change:data', this.render, this);
            //this.model.on('destroy', this.remove);
            this.model.on('change:value', function () {
                self.model.save();
                //console.log(self.model.attributes);
            });
        },

        render:function () {
            var self = this;
            if(this.model.get('data')){
                _.extend(this.allAttrs,this.model.attributes);
                this.$el.html(this.template(this.allAttrs));
                //this.$el.css("background-color","lightgray");
                //this.$(".problem").css("opacity","0.5");
                //this.$(".prob-value").on("change",this.updateProblem);

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
                if (this.model.get("displayMode")==="MathJax"){
                    MathJax.Hub.Queue(["Typeset",MathJax.Hub,this.el]);
                }

                this.stickit();
                
            } else {
                this.$el.html("<span style='font: italic 120%'>Loading Problem</span><i class='icon-spinner icon-spin icon-2x'></i>");
                this.model.loadHTML(function (data) {
                    if (data.text){
                        self.model.set("data",data.text);
                        self.render();
                    } else {
                        console.log(data);
                    }
                });
            }


            return this;
        },
        events: {"click .hide-problem": "hideProblem",
            "click .remove-problem": "removeProblem",
            "click .refresh-problem": 'reloadWithRandomSeed',
            "click .add-problem": "addProblem"},
        bindings: {".prob-value": "value"},
        reloadWithRandomSeed: function (){
            var seed = Math.floor((Math.random()*10000));
            console.log("reloading with new seed " + seed);
            this.model.set({data:"", problem_seed: seed},{silent: true});
            this.render();
        },
        addProblem: function (evt){
            console.log("adding a problem. ")
            //this.model.collection.trigger("add-to-target",this.model);
        },
        hideProblem: function(evt){
            console.log("hiding a problem ");
            $(evt.target).parent().parent().css("display","none")
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