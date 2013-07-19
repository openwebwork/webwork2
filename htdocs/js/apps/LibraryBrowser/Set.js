define(['Backbone', 'underscore', 'config', './ProblemList'], function(Backbone, _, config, ProblemList){
    
    /**
     *
     * @type {*}
     */
    var Set = Backbone.Model.extend({
        defaults:{
            name:"defaultSet"
        },
    
        initialize:function () {
            this.set('problems', new ProblemList);
            this.webserviceURL = config.webserviceURL;
            _.defaults(this.defaultRequestObject, config.requestObject);
            //this.get('problems').url = this.get('name');
            _.extend(this.defaultRequestObject, {
                set: this.get('name'),
                xml_command: "listSetProblems"
            });
    
            this.get('problems').fetch();
        }
    
    });
    
    return Set;
});