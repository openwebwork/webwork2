define(['backbone', 'underscore', 'views/ProblemView','config','models/ProblemList'], 
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

        initialize: function(options){
            var self = this;
            _.bindAll(this,"render","deleteProblem","undoDelete","reorder","addProblemView");
            

            this.problems = options.problems ? options.problems : new ProblemList();
            this.problemSet = options.problemSet; 
            this.undoStack = []; // this is where problems are placed upon delete, so the delete can be undone.  
            this.pageSize = 10; // this should be a parameter.
            this.pageRange = _.range(this.pageSize);
            this.currentPage = 1;
            _.extend(this.viewAttrs,{type: options.type});
            _.extend(this,Backbone.Events);
        },
        set: function(opts){
            this.problems = opts.problems; 
            this.problems.off("remove");
            this.problems.on("remove",this.deleteProblem);
            if(opts.problemSet){
                this.problemSet = opts.problemSet;
                this.problems.problemSet = opts.problemSet;
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
            var setName = (typeof(this.problems.problemSet)!="undefined")?this.problems.problemSet.get("set_id"): void 0;
            this.$el.html(_.template($("#problem-list-template").html(),
                                {setname: setName, displayModes: modes, editorURL: openEditorURL}));
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
            this.updatePaginator();
            this.updateNumProblems();
        }, 
        updateNumProblems: function () {
              this.$(".num-problems").html(config.msgTemplate({type: "problems_shown", 
                    opts: {probFrom: (this.pageRange[0]+1), probTo:(_(this.pageRange).last() + 1),
                         total: this.problems.size() }}));
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
            if(this.maxPages>1){
                this.$(".problem-paginator").html(_.template($("#paginator-template").html(),
                        {current_page: this.currentPage, page_start:start,page_stop:stop,num_pages:this.maxPages}));
            }
        },
        events: {"click .undo-delete-button": "undoDelete",
            "change .display-mode-options": "changeDisplayMode",
            "click #create-new-problem": "openSimpleEditor",
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
            //if(this.maxPages>15){
                this.updatePaginator();
            //}
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
            if(typeof(self.problems.problemSet) == "undefined"){
                return;
            }
            this.problems.problemSet.changingAttributes = {"problems_reordered":""};
            this.$(".problem").each(function (i) { 
                self.problems.findWhere({source_file: $(this).data("path")})
                        .set({problem_id: i+1}, {silent: true});  // set the new order of the problems.  
            });   
            this.problems.problemSet.save();
        },
        undoDelete: function(){
            if (this.undoStack.length>0){
                var prob = this.undoStack.pop();
                if(this.problems.findWhere({problem_id: prob.get("problem_id")})){
                    prob.set("problem_id",parseInt(this.problems.last().get("problem_id"))+1);
                }
                this.problems.add(prob);
                this.updatePaginator();
                this.gotoPage(this.currentPage);
                this.problemSet.trigger("change:problems",this.problemSet);
                if(this.undoStack.length==0){
                    this.$(".undo-delete-button").addClass("disabled");
                }
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
        // this is called when the problem has been removed from the problemList
        deleteProblem: function (problem){
            var self = this; 
            this.problemSet.changingAttributes = 
                {"problem_deleted": {setname: this.problemSet.get("set_id"), problem_id: problem.get("problem_id")}};
            this.problemSet.trigger("change:problems",this.problemSet);
            this.undoStack.push(problem);
            this.gotoPage(this.currentPage);
            this.$(".undo-delete-button").removeClass("disabled");
        }
    });
	return ProblemListView;
});
