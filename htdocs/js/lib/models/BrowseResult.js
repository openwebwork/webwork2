define(['Backbone', 'underscore','config', 'ProblemList'], function(Backbone, _, config, ProblemList){

    var BrowseResult = Backbone.Model.extend({
        defaults:{
            name: "",
        },
        
        initialize:function(){
            this.set('problems', new ProblemList);
            this.set('name', this.get('name').replace(/ /g, "_"));
        }
    });

    return BrowseResult;
});