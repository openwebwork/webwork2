define(['backbone', 'views/ProblemListView','models/UserProblemList'], 
    function(Backbone, ProblemListView,UserProblemList) {
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
                if(this.problemSet){
                    this.problemSet.on("change",function(m){
                        console.log(m.changed);
                    });
                }
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
            }
        });
    
    	return ProblemSetView;
});
