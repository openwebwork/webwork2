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
            _.bindAll(this,"render","addProblemView");  
            _(this).extend(_(options).pick("settings","problemSet","messageTemplate"));
            this.problems = options.problems ? options.problems : new ProblemList();
            this.problemSet = options.problemSet; 
            this.page_size = 10; // this should be a parameter.
            this.pageRange = _.range(this.page_size);
            this.currentPage = 0;
            this.show_tags = false;
            this.show_path = false; 
            _.extend(this.viewAttrs,{type: options.type});
        },
        set: function(opts){
            if(opts.problems){
                this.problems = opts.problems; 
                if(opts.problemSet){
                    this.problemSet = opts.problemSet;
                    this.problems.problemSet = opts.problemSet;
                }
            }
            _(this).extend(_(opts).pick("problem_set_view","show_path","show_tags","page_size"));
            if(_.isUndefined(this.currentPage)){
                this.currentPage = 0;
            }

            this.viewAttrs.type = opts.type || "set";
            this.viewAttrs.displayMode = this.settings.getSettingValue("pg{options}{displayMode}");
            // start with showing 10 (page_size) problems
            this.maxProblemIndex = (this.problems.length > this.page_size)?
                    this.page_size : this.problems.length;
            if(this.page_size <0) {
                this.maxProblemIndex = this.problems.length;
            }
            this.pageRange = _.range(this.maxProblemIndex);
            this.problemViews = [];
            return this;
        },
        render: function() {
            var tmpl = _.template($("#problem-list-template").html());
            this.$el.html(tmpl({show_undo: this.viewAttrs.show_undo}));
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
                                                                   problem_set_view: self.problem_set_view,
                    libraryView: self.libraryView, viewAttrs: self.viewAttrs})).render().el); 
                    
            });

            if(this.viewAttrs.reorderable){
                this.$(".prob-list").sortable({handle: ".reorder-handle", forcePlaceholderSize: true,
                                                placeholder: "sortable-placeholder",axis: "y",
                                                stop: this.reorder});
            }
            // check if all of the problems are rendered.  When they are, trigger an event
            //
            // I think this needs work.  It appears that MathJax fires lots of "Math End" signals, 
            // although why not just one. 
            // 
            // this may also be part of the many calls to render throughout the app. 
            // (Note: after further work on another branch, this may not be necessary)
            
            _(this.problemViews).each(function(pv){
                if(pv && pv.model){
                      pv.model.on("rendered", function () {
                          if(_(self.problemViews).chain().map(function(pv){
                               if(pv) {
                                    return pv.state.get("rendered");}
                                }).every().value()){
                            self.trigger("rendered");   
                          }
                      }); 
                }
            })
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

            this.maxPages = Math.ceil(this.problems.length / this.page_size);
            var start =0,
                stop = this.maxPages;
            if(this.maxPages>8){
                start = (this.currentPage-4 <0)?0:this.currentPage-4;
                stop = start+8<this.maxPages?start+8 : this.maxPages;
            }
            if(this.maxPages>1){
                var tmpl = _.template($("#paginator-template").html()); 
                this.$(".problem-paginator").html(tmpl({current_page: this.currentPage, page_start:start,               
                                                        page_stop:stop,num_pages:this.maxPages}));
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
            _(this.problemViews).each(function(pv){ if(pv){pv.set({show_path: _show})}});
            return this;
        },
        showTags: function (_show) {
            this.show_tags = _show;
            _(this.problemViews).each(function(pv){ if(pv){pv.set({show_tags: _show})}});
            return this;
        },
        firstPage: function() { this.gotoPage(0);},
        prevPage: function() {if(this.currentPage>0) {this.gotoPage(this.currentPage-1);}},
        nextPage: function() {if(this.currentPage<this.maxPages){this.gotoPage(this.currentPage+1);}},
        lastPage: function() {this.gotoPage(this.maxPages-1);},
        gotoPage: function(arg){
            this.currentPage = /^\d+$/.test(arg) ? parseInt(arg,10) : parseInt($(arg.target).text(),10)-1;
            this.pageRange = this.page_size >0 ? _.range(this.currentPage*this.page_size,
                (this.currentPage+1)*this.page_size>this.problems.size()? this.problems.size():(this.currentPage+1)*this.page_size)
                    : _.range(this.problems.length);
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
        setProblemSet: function(_set) {
            this.model = _set; 
            if(this.model){
                this.set({problemSet: this.model, problems: this.model.get("problems")});                
            }
            return this;
        },
        addProblemView: function (prob){
            if(this.pageRange.length < this.page_size){
                var probView = new ProblemView({model: prob, problem_set_view: this.problem_set_view,
                                                type: this.type, viewAttrs: this.viewAttrs});
                var numViews = this.problemViews.length; 
                probView.render().$el.data("id",this.model.get("set_id")+":"+(numViews+1));
                probView.model.set("_id", this.model.get("set_id")+":"+(numViews+1));
                this.$(".prob-list").append(probView.el);
                this.problemViews.push(probView);                
                this.pageRange.push(_(this.pageRange).last() +1);
            } 
            this.updateNumProblems();
        },
    });
	return ProblemListView;
});
