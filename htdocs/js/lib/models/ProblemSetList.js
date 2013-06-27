/* 
* This is a collection of WeBWorK Problem sets of type ProblemSet 
*
*/ 


define(['Backbone', 'underscore','config', './ProblemSet'], function(Backbone, _, config, ProblemSet){
    var ProblemSetList = Backbone.Collection.extend({
        model: ProblemSet,

        initialize: function(options){
            var self = this;
            _.bindAll(this,"fetch","addNewSet","deleteSet");
            this.on('add', this.addNewSet);
            this.on('remove', this.deleteSet);
            this.setLoaded = false; 
           },

        fetch: function(){
            var self = this;
            var requestObject = {"xml_command": 'getSets'};
            _.defaults(requestObject, config.requestObject);

            $.get(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                var newSet = [];
                _(response.result_data).each(function(set) { newSet.push(new ProblemSet(set)); });                  
                self.reset(newSet);
                self.setLoaded = true; 
                self.trigger("fetchSuccess");

            });
        },
        addNewSet: function (problemSet){
            var self = this;
            var requestObject = {"xml_command": 'createNewSet', 'selfassign' : true};
            _.extend(requestObject, problemSet.attributes);
            _.defaults(requestObject, config.requestObject);
            
            $.post(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
            });
            
        },
        deleteSet: function(problemSet){
            var self = this;
            var request = {"xml_command": "deleteProblemSet", "problem_set_name" : problemSet.name };
            _.defaults(request,config.requestObject);
            _.extend(request, problemSet.attributes);
            $.post(config.webserviceURL,request,function (data) {
                    var response = $.parseJSON(data);
                });

                
            }
    });
    return ProblemSetList;
});