/**
 *
 * This defines a set Header object.
 * 
 */

define(['backbone', 'underscore', 'config'], function(Backbone, _, config){

var SetHeader = Backbone.Model.extend({
    defaults: {
        set_id : "",
        url: "",
        set_header_html: "",
        hardcopy_header_html: "",
        set_header_content: "",
        hardcopy_header_content: ""
    },
    idAttribute: "_id",
    url: function () {
        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.get("set_id") + "/setheader" ;
    },
});

  return SetHeader;
})