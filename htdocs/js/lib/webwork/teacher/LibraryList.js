define(['Backbone', 'Underscore', '../WeBWorK', './Library'], function(Backbone, _, webwork, Library){
    
    
    /**
     *
     * @type {*}
     */
    var LibraryList = Backbone.Collection.extend({
        model:webwork.Library,
    
        initialize: function(){
            var self = this;
            this.url = "";
            this.defaultRequestObject = {
                xml_command: "listLib",
                command: "dirOnly",
                maxdepth: 0
            };
            
            this.model.set({children:new LibraryList});
            this.model.get('children').url = self.get('path')
            this.model.get('children').defaultRequestObject.library_name = this.get("path");
            
            _.defaults(this.defaultRequestObject, webwork.requestObject);
            this.syncing = false;
            this.on('syncing', function(value){self.syncing = value});
        },
    
        fetch: function(){
    
    
            var self = this;
    
            self.trigger("alert", "Loading libraries... may take some time");
            var requestObject = {};
    
            _.defaults(requestObject, this.defaultRequestObject);
            self.trigger('syncing', true);
            $.post(webwork.webserviceURL, requestObject,
                function (data) {
                    //console.log(data);
                    //try {
                    var response = $.parseJSON(data);
                    console.log(response);
                    console.log("result: " + response.server_response);
                    //need better server responses eventually
    
                    var newLibs = new Array();
    
                    //should be either an object of a comma separated list
                    var libraries = _.isArray(response.result_data)?response.result_data:_.isObject(response.result_data)?_.keys(response.result_data):response.result_data.split(",")
    
                    libraries.forEach(function(lib) {
                        newLibs.push({name:lib, path: self.url +"/"+lib})
                    });
                    self.reset(newLibs);
    
                    self.trigger("alert", response.server_response);//self.trigger('alert', {message: "string", type: "error, success, warning"});
                    self.trigger('syncing', false);
                });
        }
    });
    
    return LibraryList;
});