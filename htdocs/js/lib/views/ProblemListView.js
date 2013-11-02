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
            

            this.problems = this.options.problems ? this.options.problems : new ProblemList();
            this.problemSet = this.options.problemSet; 
            this.problems.on("remove",this.deleteProblem);
            this.undoStack = []; // this is where problems are placed upon delete, so the delete can be undone.  
            this.pageSize = 10; // this should be a parameter.
            this.pageRange = _.range(this.pageSize);
            this.currentPage = 1;
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
            // start with showing 10 (pageSize) problems
            this.maxProblemIndex = (this.problems.length > this.pageSize)?
                    this.pageSize : this.problems.length;

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
            this.updatePaginator();
            this.gotoPage(0);

            
            return this;
        }, 
        renderProblems: function () {
            var self = this;
            var ul = this.$(".prob-list").empty(); 
            _(this.pageRange).each(function(i){
                ul.append((self.problemViews[i] = new ProblemView({model: self.problems.at(i), 
                    libraryView: self.libraryView, viewAttrs: self.viewAttrs})).render().el); 
                    
            });

            if(this.viewAttrs.reorderable){
                this.$(".prob-list").sortable({handle: ".reorder-handle", forcePlaceholderSize: true,
                                                placeholder: "sortable-placeholder",axis: "y",
                                                stop: this.reorder});
            }
            this.trigger("update-num-problems",
                "Problems " + (this.pageRange[0]+1) + " to " + (_(this.pageRange).last() + 1) + " of " +
                this.problems.size());
        }, 
        updatePaginator: function() {
            // render the paginator

            this.maxPages = Math.ceil(this.problems.length / this.pageSize);
            var start =0,
                stop = this.maxPages;
            if(this.maxPages>15){
                start = (this.currentPage-7 <0)?0:this.currentPage-7;
                stop = start+15<this.maxPages?start+15 : this.maxPages;
            }
            this.$(".problem-paginator").html(_.template($("#paginator-template").html(),
                    {page_start:start,page_stop:stop,num_pages:this.maxPages}));
        },       
        loadMore: function () {
            this.maxProblemIndex+=10;
            this.renderProblems();
        },
        events: {"click #undo-delete-btn": "undoDelete",
            "change .display-mode-options": "changeDisplayMode",
            "click #create-new-problem": "openSimpleEditor",
            "click .load-more-btn": "loadMore",
            "click .show-hide-tags-btn": "toggleTags",
            "click .goto-first": "firstPage",
            "click .go-back-one": "prevPage",
            "click .page-button": "gotoPage",
            "click .go-forward-one": "nextPage",
            "click .goto-end": "lastPage"
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
                        pv.$(".tag-row").addClass("hidden");
                        pv.model.loadTags({success: function (data){
                            pv.$(".loading-row").addClass("hidden");
                            pv.$(".tag-row").removeClass("hidden");
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
        firstPage: function() { this.gotoPage(0);},
        prevPage: function() {if(this.currentPage>0) {this.gotoPage(this.currentPage-1);}},
        nextPage: function() {if(this.currentPage<this.maxPages){this.gotoPage(this.currentPage+1);}},
        lastPage: function() {this.gotoPage(this.maxPages-1);},
        gotoPage: function(arg){
            this.currentPage = /^\d+$/.test(arg) ? parseInt(arg,10) : parseInt($(arg.target).text(),10)-1;
            this.pageRange = _.range(this.currentPage*this.pageSize,
                (this.currentPage+1)*this.pageSize>this.problems.size()? this.problems.size():(this.currentPage+1)*this.pageSize);
            if(this.maxPages>15){
                this.updatePaginator();
            }
            this.renderProblems();
            this.$(".problem-paginator button").removeClass("current-page");
            this.$(".problem-paginator button[data-page='" + this.currentPage + "']").addClass("current-page");

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
