/* 
* This is a collection of WeBWorK Problem sets of type ProblemSet 
*
*/ 


define(['Backbone', 'underscore','config', './ProblemSet'], function(Backbone, _, config, ProblemSet){
    var ProblemSetList = Backbone.Collection.extend({
        model: ProblemSet,

        initialize: function(){
            var self = this;
            _.bindAll(this,"parse");
           },
        url: function () {
            return config.urlPrefix+ config.courseSettings.courseID + "/sets";
        },
        parse: function(response){
            var self = this;
            _(response).each(function(_set){
                var theSet = new ProblemSet();
                theSet.parse(_set);
                self.add(theSet);
//                self.add((new ProblemSet()).parse(_set));
            });
        }
    });
    return ProblemSetList;
});