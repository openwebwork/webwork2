//might not have to be a module.. or at least not these config files
/*
 structure styled after Three.js..kind of

 David Gage 2012
 */

define(['underscore','module'], function(_, module){
    //I want to put these in a config file built by a yeoman script
    _.extend(module.config().webwork.requestObject, {
        "xml_command":"listLib",
        "pw":"",
        "password":module.config().webwork.PASSWORD,
        "session_key":module.config().webwork.SESSIONKEY,
        "user":"user-needs-to-be-defined",
        "library_name":"Library",
        "courseID":module.config().webwork.COURSE,
        "set":"set0",
        "new_set_name":"new set",
        "command":"buildtree"
    });
    
    module.config().webwork.webserviceURL = "/webwork2/instructorXMLHandler";

    return webwork;
});