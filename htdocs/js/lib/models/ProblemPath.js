/****
pstaab: I don't think this is needed anymore. 
**/
define(['Backbone', 'underscore','config'], function(Backbone, _, config){
	var ProblemPath = Backbone.Model.extend({
        defaults: {
            path: ""
        }
    });
    return ProblemPath
});