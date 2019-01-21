


define(['Backbone', './WeBWorKProperty','underscore','config'], function(Backbone, WeBWorKProperty,_,config){
    /**
     *
     * @class webwork
     * @type Object
     * @static
     */

var Settings = Backbone.Collection.extend({ 
    model: WeBWorKProperty,
    initialize: function (){
        _.bindAll(this,"fetch","getSettingValue");
        this.on("update",this.update);
    },
    fetch: function () {
        var self=this;
        var requestObject = { xml_command: "getCourseSettings"};
        _.defaults(requestObject, config.requestObject);

        this.reset();


        $.get(config.webserviceURL, requestObject,
            function (data) {
                var response = $.parseJSON(data);
                console.log("The course settings have loaded");
                var settingsData = response.result_data;

                if (settingsData.length === 5) {
                    var tzData = settingsData.pop();
                    self.add(new WeBWorKProperty({category: "timezone", "var": "timezone", value: tzData[1]},{silent: true}));
                }

                _(settingsData).each(function(set){
                    var _category = "";
                    _(set).each(function(prop,i){
                        if (i===0) {_category = prop} else {
                            self.add(new WeBWorKProperty(_.extend(prop,{category: _category})),{silent: true});
                        }

                    });
                });
                self.trigger("fetchSuccess");
            });

            

        },
        getSettingValue: function(_setting){
            return (this.find(function(v) { return v.get("var")===_setting;})).get("value");
        }
    });
    

    
    return Settings;
});
