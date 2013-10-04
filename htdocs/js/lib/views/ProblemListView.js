define(['Backbone', 'underscore', 'views/ProblemView','config','models/ProblemList'], 
    function(Backbone, _, ProblemView,config,ProblemList){

    /******
      * 
      *  The ProblemListView is a View of the ProblemList Collection and designed to be a super class of
      *  a ProblemSetView or a LibraryProblemListView.  In short, it displays the problems in the ProblemList
      *   This is used for both a list of problems from the library (global or local) as well as a problem set. 
      * 
      *  The inherited class must define the following:
      *  viewAttrs:  an object of viewing attributes that are passed to the ProblemView to determine how it is decorated.  
      *  headerTemplate: a string of the jquery selector for the template used to render the header.
      *                     The template needs to contain a <div class="prob-list"></div> where the problems will be shown  
      *  displayModes: an array of strings of the possible display modes for problem rendering. 
      *  
      *  The set name and list of problems are passed in the setProblems function.  
      *
      */

    var ProblemListView = Backbone.View.extend({

        initialize: function(){
            var self = this;
            _.bindAll(this,"render","deleteProblem","undoDelete","reorder","addProblemView");
            
            this.numProblemsPerGroup = 10; // this should be a parameter.
            
            this.problems = this.options.problems ? this.options.problems : new ProblemList();
            this.problems.on("remove",this.deleteProblem);
            this.undoStack = []; // this is where problems are placed upon delete, so the delete can be undone.  

            // start with showing 10 (numProblemsPerGroup) problems
            this.maxProblemIndex = (this.problems.length > this.numProblemsPerGroup)?
                    this.numProblemsPerGroup : this.problems.length;
        },
        setProblems: function(_problems){
            this.problems = _problems; 

            // start with showing 10 (numProblemsPerGroup) problems
            this.maxProblemIndex = (this.problems.length > this.numProblemsPerGroup)?
                    this.numProblemsPerGroup : this.problems.length;

            return this;
        },
        render: function() {
            var self = this;
            var openEditorURL = this.problems ? "/webwork2/" + $("#hidden_courseID").val() 
                                    + "/instructor/SimplePGEditor/" 
                                    + this.problems.setName + "/" + (this.problems.length +1): "";
            this.$el.html(_.template($(this.headerTemplate).html(),
                                {displayModes: config.settings.getSettingValue("pg{displayModes}"), 
                                editorURL: openEditorURL}));
            
            
            this.renderProblems();
            
            return this;
        }, 
        renderProblems: function () {
            var self = this;
            var ul = this.$(".prob-list").empty(); 
            this.problems.each(function(problem,i){
                if(i<self.maxProblemIndex) {
                    ul.append((new ProblemView({model: problem,viewAttrs: self.viewAttrs})).render().el); 
                }
            });

            if(this.viewAttrs.reorderable){
                this.$(".prob-list").sortable({handle: ".reorder-handle", forcePlaceholderSize: true,
                                                placeholder: "sortable-placeholder",axis: "y",
                                                stop: this.reorder});
            }
            this.updateNumberOfProblems();
        },
        updateNumberOfProblems: function () {
            $("#number-of-problems").html(this.$(".prob-list li").length + " of " 
                + this.problems.size() + " problems shown.");
            if(this.$(".prob-list li").length == this.problems.size()){
                this.$(".load-more-btn").addClass("disabled");
            } else {
                this.$(".load-more-btn").removeClass("disabled");
            }
        },
        
        loadMore: function () {
            this.maxProblemIndex+=10;
            this.renderProblems();
        },

        events: {"click #undo-delete-btn": "undoDelete",
            "click .display-mode-options a": "changeDisplayMode",
            "click #create-new-problem": "openSimpleEditor",
            "click .load-more-btn": "loadMore"
        },
        changeDisplayMode: function (evt) {
            var _displayMode = $(evt.target).text().trim();
            
            this.problems.each(function(prob){
                prob.set({data: null, displayMode: _displayMode},{silent:true});
            });
            this.render();
        },
        /* when the "new" button is clicked open up the simple editor. */
        openSimpleEditor: function(){  
            console.log("opening the simple editor."); 
        },
        reorder: function (event,ui) {
            var self = this;
            console.log("I was reordered!");
            this.$(".problem").each(function (i) { 
                self.problems.findWhere({source_file: $(this).data("path")})
                        .set({problem_id: i+1}, {silent: true});  // set the new order of the problems.  
            });   
            this.problems.reorder();
        },
        undoDelete: function(){
            console.log("in undoDelete");
            if (this.undoStack.length>0){
                var prob = this.undoStack.pop();
                prob.set("problem_id",parseInt(this.problems.last().get("problem_id"))+1,{silent: true});
                this.problems.add(prob);
                prob.id=null;
                prob.save();
            }
        },
        setProblemSet: function(_set) {

            this.model = _set; 
            return this;
        },
        addProblemView: function (prob){
            var probView = new ProblemView({model: prob, type: this.type, viewAttrs: this.viewAttrs});
            this.$("#prob-list").append(probView.el);
            probView.render();
            this.problems.trigger("num-problems-shown");
        },
        deleteProblem: function (problem){
            var self = this; 
            problem.destroy({success: function (model) {
                console.log(model);
                self.undoStack.push(model);
            }});
        }
    });
	return ProblemListView;
});
