define(['Backbone', 'underscore','config', './ProblemSet'], function(Backbone, _, config, ProblemSet){
    var ProblemSetList = Backbone.Collection.extend({
        model: ProblemSet,

        initialize: function(){
            var self = this;
            this.on('add', function(problemSet){
                var self = this;
                var requestObject = {"xml_command": 'addProblemSet'};
                _.extend(requestObject, problemSet.attributes);
                _.defaults(requestObject, config.requestObject);
                
                $.post(config.webserviceURL, requestObject, function(data){
                    var response = $.parseJSON(data);
                    self.trigger("success","problem_set_added", user);
                });
                
                }, this);
            this.on('remove', function(problemSet){
                var request = {"xml_command": "deleteProblemSet", "problem_set_name" : problemSet.name };
    	    _.defaults(request,config.requestObject);
                _.extend(request, problemSet.attributes);
                console.log(request);
    	    $.post(config.webserviceURL,request,function (data) {
                    
                    console.log(data);
                    var response = $.parseJSON(data);
                    // see if the deletion was successful. 
        
                   self.trigger("success","problem_set_deleted",user);
                   return (response.result_data.delete == "success")
                });

                
            }, this);
            
           },

        fetch: function(){
            var self = this;
            var requestObject = {
                "xml_command": 'getSets'
            };
            _.defaults(requestObject, config.requestObject);

            $.get(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                console.log(response);
                
                var newSet = new Array();
                
                _(response.result_data).each(function(set) {
                    newSet.push(new ProblemSet(set));
                    
                    });
                self.reset(newSet);
                
    //            var problemSets = response.result_data;
                //self.reset(problemSets);
                self.trigger("fetchSuccess");
            });
        }
    });
    return ProblemSetList;
});