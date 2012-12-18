/* 
* This is a collection of WeBWorK Problem sets of type ProblemSet 
*
*/ 


define(['Backbone', 'underscore','config', './ProblemSet'], function(Backbone, _, config, ProblemSet){
    var ProblemSetList = Backbone.Collection.extend({
        model: ProblemSet,

        initialize: function(){
            var self = this;
            _.bindAll(this,"fetch","addNewSet","deleteSet");
            this.on('add', this.addNewSet);
            this.on('remove', this.deleteSet);

            
           },

        fetch: function(){
            var self = this;
            var requestObject = {
                "xml_command": 'getSets'
            };
            _.defaults(requestObject, config.requestObject);

            $.get(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                var newSet = new Array();
                _(response.result_data).each(function(set) { 
                    newSet.push(new ProblemSet(set)); 
                   
                });
                console.log("The Problem Sets have loaded");
                self.reset(newSet);
                self.trigger("fetchSuccess");
            });
        },
        addNewSet: function (problemSet){
            var self = this;
            var requestObject = {"xml_command": 'createNewSet'};
            _.extend(requestObject, problemSet.attributes);
            _.defaults(requestObject, config.requestObject);
            
            $.post(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                self.trigger("problem-set-added", problemSet);
            });
            
        },
        deleteSet: function(problemSet){
            var self = this;
            var request = {"xml_command": "deleteProblemSet", "problem_set_name" : problemSet.name };
            _.defaults(request,config.requestObject);
            _.extend(request, problemSet.attributes);
            console.log("deleting");
            console.log(request);
            $.post(config.webserviceURL,request,function (data) {
                    var response = $.parseJSON(data);
                    console.log(response);
                    // see if the deletion was successful. 
        
                   self.trigger("problem-set-deleted",problemSet);
                });

                
            }
    });
    return ProblemSetList;
});