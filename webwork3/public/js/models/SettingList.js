define(['backbone', './Setting','underscore','config'], function(Backbone, Setting,_,config){
    /**
     *
     * @class webwork
     * @type Object
     * @static
     */

var SettingList = Backbone.Collection.extend({ 
    model: Setting,
    getSettingValue: function(_setting){
        return (this.find(function(v) { return v.get("var")===_setting;})).get("value");
    },
    url: function () {
        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/settings";
    },
});


    
    return SettingList;
});
