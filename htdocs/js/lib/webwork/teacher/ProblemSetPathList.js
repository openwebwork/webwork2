define(['Backbone', 'underscore','config', './ProblemPath'], function(Backbone, _, config, ProblemPath){
    var ProblemSetPathList = Backbone.Collection.extend({
        model: ProblemPath,
        initialize: function (){
     
            
        },
        
        fetch: function(setName){
                                // Load in the problems.  There has to be a better way to do this.
            var self = this;
            var req = {"xml_command": "listSetProblems", "set": setName};
             _.defaults(req,config.requestObject)
            $.get(config.webserviceURL,req, function(data) {
                var response = $.parseJSON(data);
                _(response.result_data).each(function(_path) {self.add(new ProblemPath({path: _path}))});
                self.trigger("fetchSuccess");
            });

        }
    });
    return ProblemSetPathList
});