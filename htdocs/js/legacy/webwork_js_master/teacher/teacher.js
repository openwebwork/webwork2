/*
 structure styled after Three.js..kind of

 David Gage 2012
 */

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