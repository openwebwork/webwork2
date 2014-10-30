/**
  * This is a model for GradeBookRow. 
  * 
  * 
  */

define(['backbone', 'underscore','config'], 
    function(Backbone, _,config){
    var GradeBookRow = Backbone.Model.extend({
        defaults: {
            user_id: ""
        },
        idAttribute: "user_id",
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/users/" + this.get("user_id") +
            "/sets/" + this.get("set_id");
        }
    });

    return GradeBookRow;
});