define(['Backbone', 'underscore', './SetView'], function(Backbone, _, SetView){
	//##The Set view for the setlists
    var SetNameView = Backbone.View.extend({
        tagName:"li",
        template:_.template($('#setName-template').html()),

        events:{
            'click':'view'
        },

        initialize:function () {
            this.bigView = false;
            var self = this;
            this.model.get('problems').on('all', function(){self.render()}, this);
            this.model.get('problems').on('alert', function(message){alert(message);});
            this.model.on('highlight', function(){console.log("highlight "+self.model.get('name')); self.$el.addClass("contains_problem")});
        },

        render:function () {
            var self = this;

            self.$el.html(self.template({name: self.model.get('name'), problem_count: self.model.get('problems').length}));
            self.$el.droppable({
                tolerance:'pointer',

                hoverClass:'drophover',

                drop:function (event, ui) {
                    //var newProblem = new webwork.Problem({path:ui.draggable.attr("data-path")});
                    self.model.get("problems").add({path:ui.draggable.attr("data-path")});
                }
            });

            return this;
        },

        view:function () {
            console.log("clicked " + this.model.get('name'));
            if ($('#problems_container #' + this.model.get('name')).length > 0) {
                $('#problems_container').tabs('select', this.model.get('name'));
            } else {
                var view = new SetView({model:this.model});
                view.render();
            }
            //render the full tab thing, or switch to it
        }
    });
    return SetNameView;
})