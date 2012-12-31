define(['Backbone', 'underscore', 'config', 'Library'], function(Backbone, _, config, Library){
    /**
     *
     * This is a Collection of WeBWorK libraries.  Each library is one segment of the Open Problem Library (OPL). 
     */
    var LibraryList = Backbone.Collection.extend({
        model:Library,

    
        initialize: function(models, options){
            var self = this;
            this.url = "";
            this.defaultRequestObject = {
                xml_command: "listLib",
                command: "dirOnly",
                maxdepth: 0
            };
            var addChildren = function(lib){
                lib.set({children:new LibraryList});
                lib.get('children').url = lib.get('path')
                lib.get('children').defaultRequestObject.library_name = lib.get("path");
            };
            this.on('add', addChildren);
            this.on('reset', function(libs){
                libs.forEach(function(lib){addChildren(lib);});
            });
            this.webserviceURL = config.webserviceURL;
            _.defaults(this.defaultRequestObject, config.requestObject);
            this.syncing = false;
            this.on('syncing', function(value){self.syncing = value});
        },
    
        fetch: function(){
    
    
            var self = this;
    
            //self.trigger("alert", "Loading libraries... may take some time");
            var requestObject = {};
    
            _.defaults(requestObject, this.defaultRequestObject);
            self.trigger('syncing', true);
            console.log(requestObject);
            $.post(this.webserviceURL, requestObject,
                function (data) {
                    //try {
                    var response = $.parseJSON(data);
                    console.log(response);
                    console.log("result: " + response.server_response);
                    //need better server responses eventually
    
                    var newLibs = new Array();
    
                    //should be either an object of a comma separated list
                    var libraries = _.isArray(response.result_data)?response.result_data:_.isObject(response.result_data)?_.keys(response.result_data):response.result_data.split(",")
    
                    _(libraries).each(function(lib) {
                        newLibs.push({name:lib, path: self.url +"/"+lib})
                    });
                    self.reset(newLibs);
    
                   // self.trigger("alert", response.server_response);//self.trigger('alert', {message: "string", type: "error, success, warning"});
                    self.trigger('syncing', false);
                    self.trigger('fetchSuccess');
                });
        }   
    });
    
    return LibraryList;
});