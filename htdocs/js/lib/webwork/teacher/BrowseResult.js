define(['Backbone', 'underscore','../WeBWorK', '../ProblemList'], function(Backbone, _, webwork, ProblemList){

    webwork.BrowseResult = Backbone.Model.extend({
        defaults:{
            name: "",
        },
        
        initialize:function(){
            this.set('problems', new ProblemList);
            this.set('name', this.get('name').replace(/ /g, "_"));
        }
    });
});