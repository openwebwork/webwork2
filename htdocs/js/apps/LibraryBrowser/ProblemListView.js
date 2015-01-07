define(['Backbone', 'underscore', './ProblemView','config'], function(Backbone, _, ProblemView,config){

    /******
      * 
      *  The ProblemListView is a View of the ProblemList Collection.  In short, it displays the problems in the ProblemList
      *   This is used for both a list of problems from the library (global or local) as well as a problem set. 
      * 
      *  One must pass the following:
      *  type: the type of problemList (library or problemset)
      *  viewAttrs:  an object of viewing attributes that are passed to the ProblemView to determine how it is decorated.  
      *  headerTemplate: a string of the jquery selector for the template used to render the header.
      *                     The template needs to contain a <div id="prob-list"></div> where the problems will be shown.  
      *  displayModes: an array of strings of the possible display modes for problem rendering. 
      *  
      *  The set name and list of problems are passed in the setProblems function.  
      *
      */

    var ProblemListView = Backbone.View.extend({

        initialize: function(){
            var self = this;
            _.bindAll(this,"render","loadNextGroup","deleteProblem","undoDelete","reorder","addProblemView");
            this.viewAttrs = this.options.viewAttrs;
            this.type = this.options.type;
            this.headerTemplate = this.options.headerTemplate;
            this.displayModes = this.options.displayModes; 
            
            this.group_size = 25;  // this should be a setting
           
           
        },
        render: function() {
            var self = this;
            this.lastProblemShown = -1; 
            this.$el.html(_.template($(this.headerTemplate).html(),{displayModes: this.displayModes}));
            this.loadNextGroup();  
            if(this.viewAttrs.reorderable){
                this.$("#prob-list").sortable({update: this.reorder, handle: ".reorder-handle", //placeholder: ".sortable-placeholder",
                                                axis: "y"});
            }
          
        },
        events: {"click #undo-delete-btn": "undoDelete",
            "click .display-mode-options a": "changeDisplayMode"},
        setProblems: function(_problems){  // _problems should be a ProblemList
            var self = this; 


            this.undoStack = []; // this is where problems are placed upon delete, so the delete can be undone.  
        
            this.problemViews = [];  // an array of ProblemViews to render the problems. 
            this.problemsRendered = [];  // this is used to determine when all of the problems have been rendered.  

            this.problems = _problems;
            this.problems.on("remove",this.deleteProblem);

            // run this after all of the problems have been rendered. 
            // this will set the size of the window (although we should do this will CSS)
            // and showing the number of problems shown


            this.problems.on("problemRendered", function (probNumber) {  
                self.problemsRendered.push(probNumber);
                if (self.problemsRendered.length === self.problems.size()){
                    self.$el.height(0.8*$(window).height());
                    self.problems.trigger("num-problems-shown");
                }
            });
            this.problems.on("reordered",function () {
                self.hwManager.announce.addMessage({text: "Problem Set " + self.parent.problemSet.get("set_id") + " was reordered"});
            });
            this.problems.on("add", this.addProblemView);
            this.render();
        },
        changeDisplayMode: function (evt) {
            var _displayMode = $(evt.target).text().trim();
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
                var p = self.problems.find(function(prob) { return prob.get("path")===path});
                p.set({place: i}, {silent: true});  // set the new order of the problems.  
            });   
            self.collection.reorder();
        },
        undoDelete: function(){
            console.log("in undoDelete");
            if (this.undoStack.length>0){
                var prob = this.undoStack.pop();
                this.problems.addProblem(prob);
            }

        },
        addProblemView: function (prob){
            var probView = new ProblemView({model: prob, type: this.type, viewAttrs: this.viewAttrs});
            this.$("#prob-list").append(probView.el);
            probView.render();
            this.problems.trigger("num-problems-shown");
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
            if (lastProblem > self.problems.size()){
                lastProblem = self.problems.size();
                allProblemsShown = true;
            }
            var problemsToView = _.range(start,lastProblem);
            var ul = this.$("#prob-list");  
            _(problemsToView).each(function(i) {
                self.problemViews[i] =new ProblemView({model: self.problems.at(i), type: self.type, viewAttrs: self.viewAttrs});
                ul.append(self.problemViews[i].render().el);
                self.problems.trigger("problemRendered",i);
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
