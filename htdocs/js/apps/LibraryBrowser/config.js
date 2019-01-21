define([], function(){
    var webwork = {
        requestObject: {
            "xml_command":"listLib",
            "pw":"",
            "password":"",
            "session_key":document.getElementById("hidden_key").value,
            "user":document.getElementById("hidden_user").value,
            "library_name":"Library",
            "courseID":document.getElementById("hidden_courseID").value,
            "set":"set0",
            "new_set_name":"new set",
            "command":"buildtree"
        },
        webserviceURL: "/webwork2/instructorXMLHandler"
    };
    return webwork;
});