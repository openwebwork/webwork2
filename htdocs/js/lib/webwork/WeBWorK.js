
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

  /*  webwork.settings = Backbone.Model.extend({ 
        values: {
            time_assign_due: "11:59PM",
            assign_open_prior_to_due: "1 week",
            answers_open_after_due: "2 days",
            reduced_credit: true,
            reduced_credit_time: "3 days"
        },
        descriptions: {
            time_assign_due: "Time that the Assignment is Due",
            assign_open_prior_to_due: "Prior time that the Assignment is Open",
            answers_open_after_due: "Time after Due Date that Answers are Open",
            reduced_credit: "Assignment has Reduced Credit",
            reduced_credit_time: "Length of Time for Reduced Credit"
        }});

    */

    
    return webwork;
});
