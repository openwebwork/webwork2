define(['Backbone', 'underscore'], function(Backbone, _){
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
            this.model.on('change:data', this.render, this);
            if(!this.options.remove_display){
                this.options.remove_display = false;
            }
            this.model.on('destroy', this.remove, this);
        },

        render:function () {
            var problem = this.model;
            var self = this;

            if(problem.get('data')){
                var jsonInfo = this.model.toJSON();
                _.extend(jsonInfo, self.options);
                this.$el.html(this.template(jsonInfo));
                this.$el.draggable({
                    helper:'clone',
                    revert:true,
                    handle:'.problem',
                    appendTo:'body',
                    cursorAt:{
                        top:0,
                        left:0
                    },
                    opacity:0.35
                });
            } else {
                this.$el.html('<img src="/webwork2_files/images/ajax-loader.gif" alt="loading"/>');
                problem.render();
            }

            this.el.id = this.model.cid;
            this.el.setAttribute('data-path', this.model.get('path'));


            return this;
        },

        clear: function(){
            this.model.collection.remove(this.model);
            this.model.clear();
        }
    });

	return ProblemView;
});