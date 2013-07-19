define(['Backbone', 'underscore', 'ProblemList', 'config'], function(Backbone, _, ProblemList, config){
    /**
     *
     * This is a single WeBWorK library.  
     */
    var Library = Backbone.Model.extend({
        defaults:function () {
            return{
                name:"",
                path: ""
            }
        },
    
        initialize:function () {
            var self = this;
            this.set({problems:new ProblemList()});

            this.webserviceURL = config.webserviceURL;
            _.defaults(this.defaultRequestObject, config.requestObject);
    
            _.extend(this.defaultRequestObject, {
                xml_command: "listLib",
                command: "files",
                maxdepth: 0,
                library_name: self.get('path') + "/"
            });
    
        }
    });
    
    return Library;

});