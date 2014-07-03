/* 
* This is a collection of WeBWorK Problem sets of type ProblemSet 
*
*/ 


define(['Backbone', 'underscore','config', './ProblemSet'], function(Backbone, _, config, ProblemSet){
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
            var self = this;
            _(response).each(function(_set){
                var newSet = new ProblemSet(_set);
                self.add(newSet);
            });
        }
    });
    return ProblemSetList;
});