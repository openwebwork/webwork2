define(['Backbone', 'underscore', './ProblemView','config'], function(Backbone, _, ProblemView,config){

    /******
      * 
      *  The ProblemListView is a View of the ProblemList Collection.  In short, it displays the problems in the ProblemList
      *   This is used for both a list of problems from the library (global or local) as well as a problem set. 
      * 
      *  One must past a ProblemList as the collection to this view and this will display up to this.group_size problems
      *  at a time. 
      *
      */


    var ProblemListView = Backbone.View.extend({

        initialize: function(){
            var self = this;
            _.bindAll(this,"render","loadNextGroup","deleteProblem","undoDelete");
            _.extend(this,this.options);
            this.lastProblemShown = -1; 
            this.group_size = 25;
            this.undoStack = new Array(); 
            this.collection.on("remove",this.deleteProblem);
            this.problemsRendered = new Array();
            this.collection.on("problemRendered", function (probNumber) {  // run this after all of the problems have been rendered. 
                self.problemsRendered.push(probNumber);
                if (self.problemsRendered.length === self.collection.size()){
                    self.$el.height(0.8*$(window).height());
                }
            });

        },
        render: function() {
            var self = this;
            this.$el.html("<ul class='list'></ul>");
            self.$(".undo-delete-btn").on("click",this.undoDelete);
            if(this.reorderable){
                this.$(".list").sortable({update: function (event,ui) { 
                    console.log("I was reordered!");
                    self.$(".problem").each(function (i) { 
                        var path = $(this).data("path");
                        var p = self.collection.find(function(prob) { return prob.get("path")===path});
                        p.set({place: i}, {silent: true});  // set the new order of the problems.  
                    });   
                    self.collection.reorder();
                }});
            }
            //this.$el.html(this.template({enough_problems: 25, group_size: this.group_size}));

            this.loadNextGroup();
            
        },
        undoDelete: function(){
            console.log("in undoDelete");
            if (this.undoStack.length>0){
                var prob = this.undoStack.pop();
                this.collection.addProblem(prob);
                var probView = new ProblemView({model: prob, deletable: this.deletable, 
                        reorderable: this.reorderable, draggable: this.draggable});
                this.$(".list").append(probView.el);
                probView.render();
            }

        },
        deleteProblem: function (prob){
            console.log("delete");
            this.undoStack.push(prob);

            // Also may need to reset the other places in the problems. 
        },


        //Define a new function loadNextGroup so that we can just load a few problems at once,
        //otherwise things get unwieldy :P
        loadNextGroup: function(){
            var self = this; 
            var start = this.lastProblemShown+1; 
            var allProblemsShown = false; 
            self.$(".load-more-problems-btn").remove();

            
            var lastProblem = start + this.group_size; 
            if (lastProblem > self.collection.size()){
                lastProblem = self.collection.size();
                allProblemsShown = true;
            }
            var problemsToView = _.range(start,lastProblem);
            var ul = this.$(".list");  
            _(problemsToView).each(function(i) {
                var prob = self.collection.at(i);
                var probView = new ProblemView({model: prob, deletable: self.deletable, 
                        reorderable: self.reorderable, draggable: self.draggable});
                ul.append(probView.el);

                probView.render();
            });

            this.lastProblemShown = _(problemsToView).last();
            this.parent.dispatcher.trigger("num-problems-shown", lastProblem);

            if (!allProblemsShown){                
                this.$el.append("<button class='btn load-more-problems-btn'>Load " + this.group_size + " More Problems</button>");
                this.$(".load-more-problems-btn").on("click",this.loadNextGroup);
            }

            this.$el.height(0.8*$(window).height());
        }


    });
	return ProblemListView;
});
