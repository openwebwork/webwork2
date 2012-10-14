define(['Backbone', 'underscore', 'config', '../SetList'], function(Backbone, _, config, SetList){
    /**
     *
     * @param model
     */
    SetList.prototype.create = function (model) {
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
    };

    return SetList;
});