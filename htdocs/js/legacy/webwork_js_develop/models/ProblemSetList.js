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
            this.type = options.type; 
            this.setLoaded = false; 
            
           },

        fetch: function(){
            var self = this;
            var command = (this.type === "Instructor")?'getSets':'getUserSets';
            var requestObject = {"xml_command": command};
            _.defaults(requestObject, config.requestObject);

            $.get(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                var newSet = new Array();
                _(response.result_data).each(function(set) { 
                    // change some of the 0-1 Perl booleans to "yes/no"s
                    _(["enable_reduced_scoring","visible"]).each(function(_prop){
                        set[_prop] = (set[_prop]=="0")?"no":"yes";
                    });
                    newSet.push(new ProblemSet(set)); 
                });
                console.log("The Problem Sets have loaded");                    
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