define(['Backbone', 'underscore', 'Set', 'config'], function(Backbone, _, Set, config){
    /**
     *
     * @type {*}
     */
    var SetList = Backbone.Collection.extend({
        model:Set,
    
        initialize: function(model, options){
            var self = this;
            this.defaultRequestObject = {};
            this.webserviceURL = config.webserviceURL;
            _.defaults(this.defaultRequestObject, config.requestObject);
            this.syncing = false;
            this.on('syncing', function(value){self.syncing = value});
        },
    
        fetch:function () {
            var self = this;
    
            var requestObject = {
                xml_command: "listSets"
            };
            _.defaults(requestObject, this.defaultRequestObject);
            console.log(requestObject);
            self.trigger('syncing', true);
            $.post(this.webserviceURL, requestObject, function (data) {
                var response = $.parseJSON(data);
    
                var setNames = response.result_data;
                setNames.sort();
    
                var newSets = new Array();
                for (var i = 0; i < setNames.length; i++) {
                    //workAroundSetList.renderList(workAroundSetList.setNames[i]);
                    newSets.push({name:setNames[i]})
                }
                self.reset(newSets);
                self.trigger('syncing', false);
            });
        },
        create: function (model) {
            this.add(model);
            var requestObject = {
                xml_command: "createNewSet",
                new_set_name: model.name ? model.name : model.get("name")
            };
            _.defaults(requestObject, this.defaultRequestObject);
            $.post(config.webserviceURL, requestObject, function (data) {
                //try {
                var response = $.parseJSON(data);
                console.log("result: " + response.server_response);
                self.trigger('alert', response.server_response);
                self.trigger('sync');
            });
        }

    });
    
    return SetList;
});