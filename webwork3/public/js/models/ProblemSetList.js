/* 
* This is a collection of WeBWorK Problem sets of type ProblemSet 
*
*/ 


define(['backbone', 'underscore','config', './ProblemSet'], function(Backbone, _, config, ProblemSet){
    var ProblemSetList = Backbone.Collection.extend({
        model: ProblemSet,
        /*initialize: function(){
            var self = this;
            _.bindAll(this,"parse");
           },*/
        url: function () {
            return config.urlPrefix+ "courses/" + config.courseSettings.course_id + "/sets";
        },
        parse: function(response){
            return _(response).map(function(_set){
                return new ProblemSet(_set);
            });
        }
    });
    return ProblemSetList;
});