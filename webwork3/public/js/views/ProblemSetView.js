define(['backbone', 'views/ProblemListView', 'models/UserProblemList', 'models/ProblemList','moment'],
function (Backbone, ProblemListView, UserProblemList, ProblemList, moment) {
    var ProblemSetView = ProblemListView.extend({
        viewName: "Problems",
        initialize: function (options) {
            this.viewAttrs = {reorderable: true, showPoints: true, showAddTool: false, showMaxAttempts: true,
                              showEditTool: false, problem_seed: 1, showRefreshTool: true, showTools: true,
                              showViewTool: false, showHideTool: false, deletable: true,
                              draggable: false, show_undo: true, markCorrect: true};
            _(this).extend(_(options).pick("problemSet","eventDispatcher"));
            _(this).bindAll("reorder","deleteProblem");
            options.type = "problem_set";
            ProblemListView.prototype.initialize.apply(this,[options]);
            
            // this is where problems are placed upon delete, so the delete can be undone. 
            this.deletedProblems = new ProblemList(); 

            this.set({problem_set_view: this, page_size: -1});
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
            var prob = this.problemSet.problems.findWhere({problem_id: parseInt(_prob_id)});
            this.problemsToUpdate = _(this.problemSet.get("assigned_users")).map(function(_user_id){
                var upl = new UserProblemList([],{user_id: _user_id, 
                                            set_id: self.problemSet.get("set_id")});
                return upl.fetch({success: function(){ self.markProblemCorrect(upl,_prob_id)}});

            }); 
        },
        markProblemCorrect: function(_prob_list,_prob_id){
            var self = this;
            var prob = _prob_list.findWhere({problem_id: parseInt(_prob_id)});
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
        // this removes the problem _prob from the problemSet. 
        deleteProblem: function (_prob){
            var self = this; 
            if(moment.unix(this.problemSet.get("open_date")).isBefore(new moment())){
                var conf = confirm(this.messageTemplate({type: "problem_deleted_warning"}));
                
                if(! conf){
                    return;
                }
            }
            
            this.problemSet.changingAttributes = 
                {"problem_deleted": {setname: this.problemSet.get("set_id"), 
                                     problem_id: _prob.get("problem_id")}};
            this.deletedProblems.push(_(_prob.attributes).omit("_id"));
                        
            var index = _(this.problemViews).findIndex(function(pv){ 
                return pv.model.get("problem_id") == _prob.get("problem_id")});
            var viewToRemove = this.problemViews.splice(index,1);
            this.problemSet.deleteProblem(_prob);
            viewToRemove[0].remove();
            /*_(this.problemViews).each(function(pv,i){
                    pv.model.set({problem_id: (i+1), _id: self.problemSet.get("set_id")+":"+(i+1)});
                    pv.$el.data("id",self.problemSet.get("set_id")+":"+(i+1));
                }); */
        },
        undoDelete: function(){
            if (this.deletedProblems.length>0){
                this.problemSet.addProblem(this.deletedProblems.pop());
            }
        },
        setProblemSet: function(_set){
            var self = this; 
            this.problemSet = _set; 
            this.problemSet.problems.on("add",function(_prob){
                self.addProblemView(_prob);  
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
            var newProblemViews = []; 
            
            this.$(".problem").each(function (i) {
                // this determines which model the ith one is.  
                var id = $(this).data("id").split(":")[1];  // id is the ith problem_id in the reshuffled list. 
                var prob = _(oldProblems).find(function(p) {return p.problem_id == id; });
                var attrs = _.extend({},prob,{problem_id: (i+1),
                                              _id: self.model.get("set_id") + ":" + (i+1),
                                             _old_problem_id: id});
                newProblemViews[i] = _(self.problemViews).find(function(pv) { return pv.model.get("problem_id")==id});
                newProblemViews[i].model.set(attrs,{silent: true});
                newProblemViews[i].$el.data("id",self.problemSet.get("set_id")+":"+(i+1));
            }); 
            this.problemViews = newProblemViews;  
            
            this.problemSet.problems.reset(_(this.problemViews).map(function(pv) { return pv.model.attributes;}));

            this.problemSet.save({_reorder: true});
            this.problemSet.unset("_reorder");
        },
    });

    return ProblemSetView;
});
