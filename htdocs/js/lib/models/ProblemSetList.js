/* 
* This is a collection of WeBWorK Problem sets of type ProblemSet 
*
*/ 


define(['Backbone', 'underscore','config', './ProblemSet'], function(Backbone, _, config, ProblemSet){
    var ProblemSetList = Backbone.Collection.extend({
        model: ProblemSet,

        initialize: function(){
            var self = this;
            //_.bindAll(this,"fetch","addNewSet","deleteSet");
            //this.on('add', this.addNewSet);
            //this.on('remove', this.deleteSet);
            this.setLoaded = false; 
            
           },
        url: function () {
            return config.urlPrefix+ config.courseSettings.courseID + "/sets";
        },
        parse: function(response){
            config.checkForError(response);
            return response;
        }
    });
    return ProblemSetList;
});