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
            _.bindAll(this,"render","loadNextGroup","deleteProblem","undoDelete","reorder");
            this.viewAttrs = this.options.viewAttrs;
            this.type = this.options.type;
            this.parent = this.options.parent;
            this.hwManager = this.options.hwManager;
            //_.extend(this,this.options);
            this.lastProblemShown = -1; 
            this.group_size = 25;
            this.undoStack = new Array(); 
            this.collection.on("remove",this.deleteProblem);
            this.problemViews = [];  // an array of ProblemViews to render the problems. 

            // run this after all of the problems have been rendered. 
            // this will set the size of the window (although we should do this will CSS)
            // and showing the number of problems shown

            this.problemsRendered = new Array();
            this.collection.on("problemRendered", function (probNumber) {  
                self.problemsRendered.push(probNumber);
                if (self.problemsRendered.length === self.collection.size()){
                    self.$el.height(0.8*$(window).height());
                    self.collection.trigger("num-problems-shown");
                }
            });
            this.collection.on("reordered",function () {
                self.hwManager.announce.addMessage({text: "Problem Set " + self.parent.problemSet.get("set_id") + " was reordered"});
            });

        },
        render: function() {
            var self = this;
            this.$el.html(_.template($("#problem-list-template").html()));

            var displayModes = this.hwManager.settings.getSettingValue("pg{displayModes}");
            console.log(displayModes);
            this.$(".display-mode-options").append(_(displayModes).map(function(mode) {return "<option>" + mode + "</option>";}).join(""));

            $("#undo-delete-btn").on("click",this.undoDelete);
            if(this.viewAttrs.reorderable){
                this.$("#prob-list").sortable({update: this.reorder, handle: ".reorder-handle", //placeholder: ".sortable-placeholder",
                                                axis: "y"});
            }
            this.loadNextGroup();            
        },
        events: {"change .display-mode-options": "changeDisplayMode"},
        changeDisplayMode: function () {
            var _displayMode = this.$(".display-mode-options").val();
            console.log("Changing the display mode to " + _displayMode);
            _(this.problemViews).each(function(problemView) {
                problemView.model.set({data: "", displayMode: _displayMode}, {silent: true});
                problemView.render();
            });
        },
        reorder: function (event,ui) {
            var self = this;
            console.log("I was reordered!");
            self.$(".problem").each(function (i) { 
                var path = $(this).data("path");
                var p = self.collection.find(function(prob) { return prob.get("path")===path});
                p.set({place: i}, {silent: true});  // set the new order of the problems.  
            });   
            self.collection.reorder();
        },
        //events: {"click #undo-delete-btn": "undoDelete"},
        undoDelete: function(){
            console.log("in undoDelete");
            if (this.undoStack.length>0){
                var prob = this.undoStack.pop();
                this.collection.addProblem(prob);
                var probView = new ProblemView({model: prob, type: this.type, viewAttrs: this.viewAttrs});
                this.$("#prob-list").append(probView.el);
                probView.render();
                this.parent.dispatcher.trigger("num-problems-shown");
            }

        },
        deleteProblem: function (prob){
            this.undoStack.push(prob);
        },


        //Define a new function loadNextGroup so that we can just load a few problems at once,
        //otherwise things get unwieldy :P
        loadNextGroup: function(){
            console.log("in loadNextGroup");
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
            var ul = this.$("#prob-list");  
            _(problemsToView).each(function(i) {
                self.problemViews[i] =new ProblemView({model: self.collection.at(i), type: self.type, viewAttrs: self.viewAttrs});
                ul.append(self.problemViews[i].render().el);
            });

            this.lastProblemShown = _(problemsToView).last();
            

            if (!allProblemsShown){                
                this.$el.append("<button class='btn load-more-problems-btn'>Load " + this.group_size + " More Problems</button>");
                this.$(".load-more-problems-btn").on("click",this.loadNextGroup);
            }

            this.$el.height(0.8*$(window).height());
        }


    });
	return ProblemListView;
});
