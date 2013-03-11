define(['Backbone', 'underscore','jquery-imagesloaded'], function(Backbone, _){
	//##The problem View

    //A view defined for the browser app for the webwork Problem model.
    //There's no reason this same view couldn't be used in other pages almost as is.
    var ProblemView = Backbone.View.extend({
        //We want the problem to render in a `li` since it will be included in a list
        tagName:"li",
        //Add the 'problem' class to every problem
        //className: "problem",
        //This is the template for a problem, the html is defined in SetMaker3.pm
        template: _.template($('#problem-template').html()),

        //Register events that a problem's view should listen for,
        //in this case it removes the problem if the button with class 'remove' is clicked.
        events:{
            "click .remove": 'clear'
        },

        //In most model views initialize is used to set up listeners
        //on the views model.
        initialize:function () {
            _.bindAll(this,"render","updateProblem","clear");
            _.extend(this.model.attributes,this.options);
            this.model.on('change:data', this.render, this);
            this.model.on('destroy', this.remove, this);
        },

        render:function () {
            var self = this;
            if(this.model.get('data')){
                this.$el.html(this.template(this.model.toJSON()));
                this.$el.addClass("problem");
                this.$el.css("background-color","lightgray");
                this.$(".problem").css("opacity","0.5");
                if (this.model.get("draggable")) {
                    this.$el.draggable({
                        helper:'clone',
                        revert:true,
                        handle:'.problem',
                        appendTo:'body',
                        //cursorAt:{top:0,left:0}, 
                        //opacity:0.65
                    }); 

                } 
                this.$(".prob-value").on("change",this.updateProblem);
                this.model.trigger("problemRendered",this.model.get("place"));
                

                var dfd = this.$el.imagesLoaded();
                dfd.done( function( $images ){

                    self.$el.removeAttr("style");
                    self.$(".problem").removeAttr("style");
                    self.$(".loading").remove();
                });
                
            } else {
                this.$el.html("<img src='/webwork2_files/images/ajax-loader-small.gif' alt='loading'/>");
                this.model.fetch();
            }

            this.el.id = this.model.cid;
            this.$el.attr('data-path', this.model.get('path'));
            this.$el.attr('data-source', this.model.get('type'));


            return this;
        },
        updateProblem: function(evt)
        {
            this.model.update({value: $(evt.target).val()});
        },
        clear: function(){
            this.model.collection.remove(this.model);
            this.model.clear();

            // update the number of problems shown
        }
    });

	return ProblemView;
});