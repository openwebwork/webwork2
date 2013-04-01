define(['Backbone', 'underscore', 'config'], function(Backbone, _, config){
    /**
     *
     * This defines a single webwork Problem.
     * 
     * @type {*}
     */
    var Problem = Backbone.Model.extend({
        defaults:function () {
            return{
                path:"",
                data: null,
                place: 0,
                value: 1,
            };
        },
    
        initialize:function () {
            _.bindAll(this,"fetch","update");
        },
        //this is a server render, different from a view render
        fetch: function () {
            var self = this;
            var requestObject = {
                problemSource: this.get('path'),
                xml_command: "renderProblem"
            };
            _.defaults(requestObject, config.requestObject);
    
    
            if (!this.get('data')) {
                //if we haven't gotten this problem yet, ask for it
                $.post(config.webserviceURL, requestObject, function (data) {
                    self.set('data', data);
                });
            }
        },
        clear: function() {
            this.destroy();
        },
        update: function(props)
        {
            console.log("in Problem Update");
            var self = this; 
            var requestObject = {
                xml_command: "updateProblem",
                set_id: this.collection.setName,
                path: this.get("path"),
                place: this.get("place"),
                value: this.get("value")
            };
            _.defaults(props,requestObject);
            _.defaults(props, config.requestObject);
            console.log(props);
             $.post(config.webserviceURL, props, function (data) {
                    console.log("updated problem");
                    self.set(props);
                });

        }
    });
    
    return Problem;
});