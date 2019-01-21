define(['Backbone', 'underscore', './ProblemView'], function(Backbone, _, ProblemView){
	    //##The main Set view
    var SetView = Backbone.View.extend({
        template:_.template($('#set-template').html()),
        events:{
        },

        initialize:function () {
            var self = this;
            this.model.get('problems').on('add', function(model){self.addOne(model)}, this);
            this.model.get('problems').on('reset', function(){self.addAll();}, this);
            this.model.get('problems').on('all', function(){
                $("[href=#"+self.model.get('name')+"]").html(self.model.get('name') + " (" + self.model.get('problems').length + ")");
            }, this);
            this.model.get('problems').on('alert', function(message){alert(message);});

            this.model.get('problems').on('syncing', function(value){
                if(value){
                    $("[href=#"+self.model.get('name')+"]").addClass("syncing");
                } else {
                    $("[href=#"+self.model.get('name')+"]").removeClass("syncing");
                }
            }, this);

        },

        render:function () {

            var self = this;
            if ($('#problems_container #' + this.model.get('name')).length == 0) {
                $('#problems_container').tabs('add', "#"+this.model.get('name'), this.model.get('name') + " (" + this.model.get('problems').length + ")"); //could move to an after?
                this.setElement(document.getElementById(this.model.get('name')));
            }

            this.$el.html(self.template(self.model.toJSON()));

            if(self.model.get('problems').syncing){
                $("[href=#"+self.model.get('name')+"]").addClass("syncing");
            }

            this.$('.list').sortable({
                axis:'y',
                start:function (event, ui) {
                    //self.previousOrder = $(this).sortable('toArray');
                },
                update:function (event, ui) {
                    //self.reorderProblems($(this).sortable('toArray'));
                    var newOrder = self.$('.list').sortable('toArray');
                    for(var i = 0; i < newOrder.length; i++){
                        var problem = self.model.get('problems').getByCid(newOrder[i]);
                        if(problem){
                            problem.set('place', i);
                        }
                    }

                    self.model.get('problems').reorder();
                }
            });

            this.addAll();
            return this;
        },

        addOne: function(problem){
            var view = new ProblemView({model:problem, remove_display: false});
            var rendered_problem = view.render().el;
            this.$(".list").append(rendered_problem);
            this.$('.list').sortable('refresh');

        },

        addAll: function(){
            var self = this;
            this.model.get('problems').each(function(model){self.addOne(model)});
        }
    });
	return SetView;
});