define(['backbone', 'views/ProblemListView','models/UserProblemList','models/ProblemList'], 
function(Backbone, ProblemListView,UserProblemList,ProblemList) {
    var ProblemSetView = ProblemListView.extend({
        viewName: "Problems",
        initialize: function (options) {
            this.viewAttrs = {reorderable: true, showPoints: true, showAddTool: false, showMaxAttempts: true,
                              showEditTool: false, problem_seed: 1, showRefreshTool: true, 
                              showViewTool: false, showHideTool: false, deletable: true, 
                              draggable: false, show_undo: true, markCorrect: true};
            _(this).extend(_(options).pick("problemSet","eventDispatcher"));
            options.type = "problem_set";
            ProblemListView.prototype.initialize.apply(this,[options]);
            
            // this is where problems are placed upon delete, so the delete can be undone. 
            this.deletedProblems = new ProblemList(); 

            this.set({problem_set_view: this});
        },
        render: function () {
          ProblemListView.prototype.render.apply(this);  
          this.$(".prob-list-container").height($(window).height()-((this.maxPages==1) ? 200: 250));
        },
        // this is a method that will mark the problem with id problem_id as correct (status=1) 
        //for all assigned users. 
        //
        // (note: alternatively, we can make a method on the backend to handle all this)

        markAllCorrect: function(_prob_id){
            var self = this;
            var prob = this.problemSet.problems.findWhere({problem_id: _prob_id});
            this.problemsToUpdate = _(this.problemSet.get("assigned_users")).map(function(_user_id){
                var upl = new UserProblemList([],{user_id: _user_id, 
                                            set_id: self.problemSet.get("set_id")});
                return upl.fetch({success: function(){ self.markProblemCorrect(upl,_prob_id)}});

            }); 
        },
        markProblemCorrect(_prob_list,_prob_id){
            var self = this;
            var prob = _prob_list.findWhere({problem_id: _prob_id});
            //var prob = _(_prob_list.models).find(function(prob) {return prob.get("problem_id")==_prob_id;})
            prob.set({status: 1}).save(prob.attributes,{success: function () {
                var msg = {type: "problem_updated",
                                      opts: {set_id: _prob_list.set_id,
                                             user_id: _prob_list.user_id,
                                             problem_id: _prob_id}}; 
                self.eventDispatcher.trigger("add-message",{type: "success",
                    short: self.messageTemplate(msg),
                    text:self.messageTemplate(msg)});
                //console.log(self);

            }});
        },
        // this is called when the problem has been removed from the problemList
        deleteProblem: function (problem){
            var self = this; 
            this.problemSet.changingAttributes = 
                {"problem_deleted": {setname: this.problemSet.get("set_id"), 
                                     problem_id: problem.get("problem_id")}};
            this.deletedProblems.push(problem);
            this.problemSet.problems.each(function(_prob,i){
                _prob.set({problem_id: (i+1),_id: self.model.get("set_id") + ":" + (i+1)},{silent: true});   
            });
            var index = _(this.problemViews).findIndex(function(pv){ 
                return pv.model.get("problem_id") == problem.get("problem_id")});
            var viewToRemove = this.problemViews.splice(index,1);
            viewToRemove[0].remove();
            
        },
        undoDelete: function(){
            if (this.deletedProblems.length>0){
                this.problemSet.addProblem(this.deletedProblems.pop());
                //this.gotoPage(this.currentPage);
            }
        },
        setProblemSet: function(_set){
            var self = this; 
            this.problemSet = _set; 
            this.problemSet.problems.on("add",function(_prob){
                //console.log("problem added to set " + self.problemSet.get("set_id"));
                self.addProblemView(_prob);
                //console.log(_prob.attributes);
            }).on("remove",function(_prob){
                //console.log("problem removed from set " + self.problemSet.get("set_id"));
                self.deleteProblem(_prob);
                //console.log(_prob.attributes);
            });

            ProblemListView.prototype.setProblemSet.call(this,_set);
            return this;
        },
        reorder: function (event,ui) {
            var self = this;
            if(typeof(this.problemSet) == "undefined"){
                return;
            }
            var oldProblems = this.problemSet.problems.map(function(p) { return _.clone(p.attributes); });
            //var newProblems = []; 
            this.$(".problem").each(function (i) {
                var id = $(this).data("id").split(":")[1];
                var prob = _(oldProblems).find(function(p) {return p.problem_id == id; });
                var attrs = _.extend({},prob,{problem_id: (i+1),_id: self.model.get("set_id") + ":" + (i+1),
                                             _old_problem_id: id});
                self.problemSet.problems.at(i).set(attrs,{silent: true});
                //newProblems.push(attrs); 
                $(this).data("id",self.problemSet.get("set_id")+":"+(i+1));
            });
            this.problemViews = _(this.problemViews).sortBy(function(pv) {return parseInt(pv.model.get("problem_id"));});

            this.problemSet.problems.each(function(p) { console.log(p.get("problem_id") + " : " + p.get("source_file"));}); 
            this.problemSet.save({_reorder: true});
            this.problemSet.unset("_reorder");
        },
    });

    return ProblemSetView;
});
