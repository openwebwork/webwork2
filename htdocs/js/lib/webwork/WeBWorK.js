
/*
    structure styled after Three.js..kind of

    David Gage 2012

    requires backbone.js, underscore.js, and their dependencies
*/

/**
 The WeBWorK javascript framework

 @module WeBWorK
 @main webwork
 **/

/**
 * Global stuff
 * should do something better with this
 * maybe I can move it to the yeoman script per app..
 */
// undo and redo functions
var undoing = false;
var undo_stack = new Array();

define(['Backbone', 'underscore'], function(Backbone, _){
    /**
     *
     * @class webwork
     * @type Object
     * @static
     */
    var webwork = webwork || { REVISION: '0.01' };
    
    /**
     The current logged in user
    
     @property USER
     @type String
     @default "user-needs-to-be-defined-in-hidden-variable-id=hidden_user"
     **/
    webwork.USER = "user-needs-to-be-defined-in-hidden-variable-id=hidden_user";
    /**
     The current course
    
     @property COURSE
     @type String
     @default "course-needs-to-be-defined-in-hidden-variable-id=hidden_courseID"
     **/
    webwork.COURSE = "course-needs-to-be-defined-in-hidden-variable-id=hidden_courseID";
    /**
     The session key regestered with the webwork server
    
     @property SESSIONKEY
     @type String
     @default "session-key-needs-to-be-defined-in-hidden-variable-id=hidden_key"
     **/
    webwork.SESSIONKEY = "session-key-needs-to-be-defined-in-hidden-variable-id=hidden_key"
    /**
     The password, I don't think this is actually used at the moment
    
     @property PASSWORD
     @type String
     @default "who-cares-what-the-password-is"
     **/
    webwork.PASSWORD = "who-cares-what-the-password-is";
    // request object, I'm naming them assuming there may be different versions
    /**
     * @property requestObject
     * @type {Object}
     * @default {
     "xml_command":"",
     "pw":"",
     "password":webwork.PASSWORD,
     "session_key":webwork.SESSIONKEY,
     "user":"user-needs-to-be-defined",
     "library_name":"Library",
     "courseID":webwork.COURSE,
     "set":"set0",
     "new_set_name":"new set",
     "command":""
     }
     */
    webwork.requestObject = {
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
    };
    
    /**
     * The url for requests to be sent, a local version is usually used instead.
     *
     * @property webserviceURL
     * @type {String}
     * @default ""
     */
    webwork.webserviceURL = "";
    
    return webwork;
});
