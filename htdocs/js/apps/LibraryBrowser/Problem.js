define(['Backbone', 'underscore', 'config'], function(Backbone, _, config){
    /**
     *
     * @type {*}
     */
    var Problem = Backbone.Model.extend({
        defaults:function () {
            return{
                path:"",
                data:false,
                place: 0
            };
        },
    
        initialize:function () {
    
        },
        //this is a server render, different from a view render
        render:function () {
            var problem = this;
            var requestObject = {
                set: this.get('path'),
                problemSource: this.get('path'),
                path: this.get('path'),
                xml_command: "renderProblem"
            };
            _.defaults(requestObject, config.requestObject);
    
    
            if (!problem.get('data')) {
                //if we haven't gotten this problem yet, ask for it
                $.post(config.webserviceURL, requestObject, function (data) {
                    problem.set('data', data);
                });
            }
        },
        clear: function() {
            this.destroy();
        }
    });
    
    return Problem;
});