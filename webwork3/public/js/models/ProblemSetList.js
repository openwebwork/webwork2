/* 
* This is a collection of WeBWorK Problem sets of type ProblemSet 
*
*/ 


define(['backbone', 'underscore','config', './ProblemSet'], function(Backbone, _, config, ProblemSet){
    var ProblemSetList = Backbone.Collection.extend({
        initialize: function(models,options){
            Backbone.Collection.prototype.initialize(models,options);
            this.dateSettings = options.dateSettings; // this stores information about standard due,reduced_credit and answer dates.
        },
        model: ProblemSet,
        setSortField: function(field){
            this.comparator=field;
            return this;
        },
        comparator: null,
        url: function () {
            return config.urlPrefix+ "courses/" + config.courseSettings.course_id + "/sets";
        },
        parse: function(response){
            var self = this;
            return _(response).map(function(_set){
                return new ProblemSet(_set,self.dateSettings);
            });
        }
    });
    return ProblemSetList;
});