define(['backbone', './UserSet'], function(Backbone, UserSet){
    return  UserSet.extend({ idAttribute: "set_id"});
});
