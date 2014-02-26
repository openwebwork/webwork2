define(['Backbone', './WeBWorKProperty','underscore','config'], function(Backbone, WeBWorKProperty,_,config){
    /**
     *
     * @class webwork
     * @type Object
     * @static
     */

var Settings = Backbone.Collection.extend({ 
    model: WeBWorKProperty,
    getSettingValue: function(_setting){
        return (this.find(function(v) { return v.get("var")===_setting;})).get("value");
    },
    url: function () {
        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/settings";
    },
    parse: function(data){
        /*var models = [];
        var self = this;
        if (data.length === 6) {  // this is a hack.  The timezone comes in the last array slot, but could be better. 
                var tzData = data.pop();
                models.push({category: "timezone", "var": "timezone", value: tzData[1]});
            }

            _(data).each(function(set){
                var _category = "";
                _(set).each(function(prop,i){
                    if (i===0) {_category = prop} else {
                        models.push(_.extend(prop,{category: _category}));
                    }

                });
            });
        return models; */

        return data;
    }
});


    
    return Settings;
});
