/** 
 *  This is a backbone collection of GradeBookRow
 *
 *   There are two types of UserSetLists:  
 *      users: a list of userSets for a given problemsSet (that is a list of users) 
 *      sets: a list of userSets for a given user (this is a list of problemSets) 
 *   
 *   If the type is not defined, then an error will be thrown. 
 */


define(['backbone','models/GradeBookRow','config'], function(Backbone,GradeBookRow,config){
    var GradeBook = Backbone.Collection.extend({
        model: GradeBookRow,
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/gradebook";                   
            }
        });

    return GradeBook;
});