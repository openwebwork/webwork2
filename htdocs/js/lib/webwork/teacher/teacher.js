//might not have to be a module.. or at least not these config files
/*
 structure styled after Three.js..kind of

 David Gage 2012
 */

define(['Underscore','../WebWorK'], function(_, webwork){
    //I want to put these in a config file built by a yeoman script
    _.extend(webwork.requestObject, {
        "xml_command":"listLib",
        "pw":"",
        "password":webwork.PASSWORD,
        "session_key":webwork.SESSIONKEY,
        "user":"user-needs-to-be-defined",
        "library_name":"Library",
        "courseID":webwork.COURSE,
        "set":"set0",
        "new_set_name":"new set",
        "command":"buildtree"
    });
    
    webwork.webserviceURL = "/webwork2/instructorXMLHandler";
});