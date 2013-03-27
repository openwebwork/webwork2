define(['Backbone', 'underscore','config','jquery-imagesloaded'], function(Backbone, _,config){
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
            _.bindAll(this,"render","updateProblem","clear");
            // this.options.viewAttrs will determine which tools are shown on the problem
            this.allAttrs = {};
            _.extend(this.allAttrs,this.options.viewAttrs,{type: this.options.type});

            var thePath = this.model.get("path").split("templates/")[1];
            var probURL = "?effectiveUser=" + config.requestObject.user + "&editMode=SetMaker&displayMode=images&key=" 
                + config.requestObject.session_key 
                + "&sourceFilePath=" + thePath + "&user=" + config.requestObject.user + "&problemSeed=1234";
            _.extend(this.allAttrs,{editUrl: "../pgProblemEditor/Undefined_Set/1/" + probURL, viewUrl: "../../Undefined_Set/1/" + probURL});
            this.model.on('change:data', this.render, this);
            this.model.on('destroy', this.remove, this);
        },

        render:function () {
            var self = this;
            if(this.model.get('data')){
                _.extend(this.allAttrs,this.model.attributes);
                this.$el.html(this.template(this.allAttrs));
                this.$el.css("background-color","lightgray");
                this.$(".problem").css("opacity","0.5");
                this.$(".prob-value").on("change",this.updateProblem);
                this.model.collection.trigger("problemRendered",this.model.get("place"));
                
                // if images  mode is used
                var dfd = this.$el.imagesLoaded();
                dfd.done( function( $images ){

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

                if(this.model.get("displayMode")==="MathJax"){
                    MathJax.Hub.Queue(["Typeset",MathJax.Hub,this.el]);
                }
                
            } else {
                this.$el.html("<img src='/webwork2_files/images/ajax-loader-small.gif' alt='loading'/>");
                this.model.fetch();
            }

            this.el.id = this.model.cid;
            this.$el.attr('data-path', this.model.get('path'));
            this.$el.attr('data-source', this.allAttrs.type);

            return this;
        },
        events: {"click .hide-problem": "hideProblem",
            "click .remove": 'clear',
            "click .refresh-problem": 'reloadWithRandomSeed',
            "click .add-problem": "addProblem"},
        reloadWithRandomSeed: function (){
            var seed = Math.floor((Math.random()*10000));
            this.model.set({data:"", problemSeed: seed},{silent: true});

            this.render();
        },
        addProblem: function (evt){
            this.model.collection.trigger("add-to-target",this.model);
        },
        hideProblem: function(evt){
            $(evt.target).parent().parent().css("display","none")
        },
        updateProblem: function(evt)
        {
            this.model.update({value: $(evt.target).val()});
        },
        clear: function(){
            console.log("removing problem");
            this.model.collection.remove(this.model);
            this.model.clear();

            // update the number of problems shown
        }
    });

	return ProblemView;
});