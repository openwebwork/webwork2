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
            this.problemSet = this.options.problemSet; 
            this.problems.on("remove",this.deleteProblem);
            this.undoStack = []; // this is where problems are placed upon delete, so the delete can be undone.  

            // start with showing 10 (numProblemsPerGroup) problems
            this.maxProblemIndex = (this.problems.length > this.numProblemsPerGroup)?
                    this.numProblemsPerGroup : this.problems.length;
            _.extend(this.viewAttrs,{type: this.options.type});
            _.extend(this,Backbone.Events);
        },
        set: function(opts){
            this.problems = opts.problems; 
            this.problems.on("remove",this.deleteProblem);
            if(opts.problemSet){
                this.problemSet = opts.problemSet;
            }
            this.viewAttrs.type = opts.type || "set";
            this.viewAttrs.displayMode = opts.displayMode || config.settings.getSettingValue("pg{options}{displayMode}").slice(0);
            // start with showing 10 (numProblemsPerGroup) problems
            this.maxProblemIndex = (this.problems.length > this.numProblemsPerGroup)?
                    this.numProblemsPerGroup : this.problems.length;

            this.problemViews = [];
            return this;
        },
        render: function() {
            var self = this;
            var openEditorURL = this.problems ? "/webwork2/" + $("#hidden_courseID").val() 
                                    + "/instructor/SimplePGEditor/" 
                                    + this.problems.setName + "/" + (this.problems.length +1): "";
            var modes = config.settings.getSettingValue("pg{displayModes}").slice();
            modes.push("None");
            this.$el.html(_.template($("#problem-list-template").html(),
                                {displayModes: modes, editorURL: openEditorURL}));
            this.renderProblems();
            
            return this;
        }, 
        renderProblems: function () {
            var self = this;
            var ul = this.$(".prob-list").empty(); 
            this.problems.each(function(problem,i){
                if(i<self.maxProblemIndex) {
                    ul.append((self.problemViews[i] = new ProblemView({model: problem, libraryView: self.libraryView,
                        viewAttrs: self.viewAttrs})).render().el); 
                    
                }
            });

            if(this.viewAttrs.reorderable){
                this.$(".prob-list").sortable({handle: ".reorder-handle", forcePlaceholderSize: true,
                                                placeholder: "sortable-placeholder",axis: "y",
                                                stop: this.reorder});
            }
            this.trigger("update-num-problems",
                {number_shown: this.$(".prob-list li").length, total: this.problems.size()});
            if(this.$(".prob-list li").length < this.problems.size()){
                this.$(".load-more-btn").removeAttr("disabled");
            } else {
                this.$(".load-more-btn").attr("disabled","disabled");
            }
        },        
        loadMore: function () {
            this.maxProblemIndex+=10;
            this.renderProblems();
        },
        events: {"click #undo-delete-btn": "undoDelete",
            "change .display-mode-options": "changeDisplayMode",
            "click #create-new-problem": "openSimpleEditor",
            "click .load-more-btn": "loadMore",
            "click .show-hide-tags-btn": "toggleTags"
        },
        changeDisplayMode: function (evt) {
            this.problems.each(function(problem){
                problem.set({data: null},{silent:true});
            });
            this.viewAttrs.displayMode = $(evt.target).val();
            this.renderProblems();
        },
        toggleTags: function () {
            if(this.$(".show-hide-tags-btn").text()==="Show Tags"){
                this.$(".show-hide-tags-btn").button("hide");
                this.$(".tag-row").removeClass("hidden");
                _(this.problemViews).each(function(pv){
                    if(!pv.tagsLoaded){
                        pv.$(".loading-row").removeClass("hidden");
                        pv.model.loadTags({success: function (data){
                            pv.$(".loading-row").addClass("hidden");
                            pv.stickit();
                            pv.tagsLoaded=true;
                        }});
                    }
                });
            } else {
                this.$(".show-hide-tags-btn").button("reset");
                this.$(".tag-row").addClass("hidden");
            }
            
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
            this.problems.reorder(function() {
                if(self.model) {
                    self.model.alteredAttributes=[{attr: "problems",
                         msg: "The problems have been reordered for Problem Set " + self.model.get("set_id")}];
                    self.model.trigger("sync",self.model);
                }    
            });
            
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
            this.set({problems: this.model.get("problems")});
            return this;
        }, 
        addProblemView: function (prob){
            var probView = new ProblemView({model: prob, type: this.type, viewAttrs: this.viewAttrs});
            this.$("#prob-list").append(probView.el);
            probView.render();
            this.trigger("update-num-problems",
                {number_shown: this.$(".prob-list li").length, total: this.problems.size()});

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
