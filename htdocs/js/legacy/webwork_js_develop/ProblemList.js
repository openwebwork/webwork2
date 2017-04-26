define(['Backbone', 'underscore', 'config', './Problem'], function(Backbone, _, config, Problem){
    /**
     *
     * @type {*}
     */
    ProblemList = Backbone.Collection.extend({
        model:Problem,
    
        initialize: function(model, options){
            var self = this;
            this.defaultRequestObject = {
    
            };
            
            this.webserviceURL = config.webserviceURL;
            _.defaults(this.defaultRequestObject, config.requestObject);

            if(this.addProblem && this.removeProblem){
                this.on('add', this.addProblem, this);
                this.on('remove', this.removeProblem, this);
            }
            this.syncing = false;
            this.on('syncing', function(value){self.syncing = value});
        },
    
        comparator: function(problem) {
            return problem.get("place");
        },
    
        //maybe move to problem list as fetch (with a set name argument)
        fetch:function () {
            var self = this;
    
            //command needs to be set in the higher model since there are several versions of problem lists
    
            var requestObject = {};
            _.defaults(requestObject, this.defaultRequestObject);
            self.trigger('syncing', true);
            $.post(config.webserviceURL, requestObject,
                function (data) {
    
                    var response = $.parseJSON(data);
    
                    var problems = response.result_data;
    
                    var newProblems = new Array();
                    for (var i = 0; i < problems.length; i++) {
                        if (problems[i] != "") {
                            newProblems.push({path:problems[i], place:i});
                        }
                    }
                    self.reset(newProblems);
                    //self.trigger('sync');
                    self.trigger('syncing', false);
                }
            );
        }
    });
    
    return ProblemList;
});