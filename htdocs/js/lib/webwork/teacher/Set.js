//different from add I hope
webwork.SetList.prototype.create = function (model) {
    this.add(model);
    var requestObject = {
        xml_command: "createNewSet",
        new_set_name: model.name ? model.name : model.get("name")
    };
    _.defaults(requestObject, this.defaultRequestObject);
    $.post(webwork.webserviceURL, requestObject, function (data) {
        //try {
        var response = $.parseJSON(data);
        console.log("result: " + response.server_response);
        webwork.alert(response.server_response);
        /*} catch (err) {
         showErrorResponse(data);
         }*/
    });
};