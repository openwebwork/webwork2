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
            _(this).extend(_(options).pick("settings","problemSet","messageTemplate"));
            this.problems = options.problems ? options.problems : new ProblemList();
            this.problemSet = options.problemSet; 
            this.undoStack = []; // this is where problems are placed upon delete, so the delete can be undone.  
            this.pageSize = 10; // this should be a parameter.
            this.pageRange = _.range(this.pageSize);
            this.currentPage = 0;
            this.show_tags = false;
            this.show_path = false; 
            _.extend(this.viewAttrs,{type: options.type});
        },
        set: function(opts){
            if(opts.problems){
                this.problems = opts.problems; 
                this.problems.off("remove").on("remove",this.deleteProblem);
                if(opts.problemSet){
                    this.problemSet = opts.problemSet;
                    this.problems.problemSet = opts.problemSet;
                }
            }
            if(opts.current_page){
                this.currentPage = opts.current_page || 0;
            }
            if(opts.show_path|| opts.show_tags){
                _(this).extend(_(opts).pick("show_path","show_tags"))
            }
            this.viewAttrs.type = opts.type || "set";
            this.viewAttrs.displayMode = this.settings.getSettingValue("pg{options}{displayMode}");
            // start with showing 10 (pageSize) problems
            this.maxProblemIndex = (this.problems.length > this.pageSize)?
                    this.pageSize : this.problems.length;
            this.pageRange = _.range(this.maxProblemIndex);
            this.problemViews = [];
            return this;
        },
        render: function() {
            this.$el.html(_.template($("#problem-list-template").html(),{show_undo: this.viewAttrs.show_undo}));
            _(this.problemViews).each(function(pv){
                pv.rendered = false;  
            })
            this.updatePaginator().gotoPage(this.currentPage || 0);
            if(this.libraryView && this.libraryView.libProblemListView){
                this.libraryView.libraryProblemsView.highlightCommonProblems();
            }
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
            this.showPath(this.show_path);
            this.showTags(this.show_tags);
            this.updatePaginator();
            this.updateNumProblems();
            return this;
        },
        /* Clear the problems and rerender */ 
        reset: function (){
            this.problemViews = [];
            this.set({problems: new ProblemList()}).render();
        },
        updateNumProblems: function () {
            if (this.problems.size()>0){
                this.$(".num-problems").html(this.messageTemplate({type: "problems_shown", 
                    opts: {probFrom: (this.pageRange[0]+1), probTo:(_(this.pageRange).last() + 1),
                         total: this.problems.size() }}));
            }
        },
        updatePaginator: function() {
            // render the paginator

            this.maxPages = Math.ceil(this.problems.length / this.pageSize);
            var start =0,
                stop = this.maxPages;
            if(this.maxPages>8){
                start = (this.currentPage-4 <0)?0:this.currentPage-4;
                stop = start+8<this.maxPages?start+8 : this.maxPages;
            }
            if(this.maxPages>1){
                this.$(".problem-paginator").html(_.template($("#paginator-template").html(),
                        {current_page: this.currentPage, page_start:start,page_stop:stop,num_pages:this.maxPages}));
            }
            return this;
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
        showPath: function(_show){
            this.show_path = _show;
            _(this.problemViews).each(function(pv){ pv.set({show_path: _show})});
            return this;
        },
        showTags: function (_show) {
            this.show_tags = _show;
            _(this.problemViews).each(function(pv){ pv.set({show_tags: _show})});
            return this;
        },
        firstPage: function() { this.gotoPage(0);},
        prevPage: function() {if(this.currentPage>0) {this.gotoPage(this.currentPage-1);}},
        nextPage: function() {if(this.currentPage<this.maxPages){this.gotoPage(this.currentPage+1);}},
        lastPage: function() {this.gotoPage(this.maxPages-1);},
        gotoPage: function(arg){
            this.currentPage = /^\d+$/.test(arg) ? parseInt(arg,10) : parseInt($(arg.target).text(),10)-1;
            this.pageRange = _.range(this.currentPage*this.pageSize,
                (this.currentPage+1)*this.pageSize>this.problems.size()? this.problems.size():(this.currentPage+1)*this.pageSize);
            
            this.updatePaginator();       
            this.renderProblems();
            this.$(".problem-paginator button").removeClass("current-page");
            this.$(".problem-paginator button[data-page='" + this.currentPage + "']").addClass("current-page");
            this.trigger("page-changed",this.currentPage);
            return this;
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
                    this.$(".undo-delete-button").attr("disabled","disabled");
                }
            }
        },
        setProblemSet: function(_set) {
            this.model = _set; 
            if(this.model){
                this.set({problemSet: this.model, problems: this.model.get("problems")});                
            }
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
            this.$(".undo-delete-button").removeAttr("disabled");
        }
    });
	return ProblemListView;
});
