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
 */
// undo and redo functions
var undoing = false;
var undo_stack = new Array();
var redo_stack = new Array();

/**
 *
 * @class webwork
 * @type Object
 * @static
 */
var webwork = webwork || { REVISION: '0' };

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
};

/**
 * The url for requests to be sent, a local version is usually used instead.
 *
 * @property webserviceURL
 * @type {String}
 * @default ""
 */
webwork.webserviceURL = "";

/**
 *
 * @type {*}
 */
webwork.Problem = Backbone.Model.extend({
    defaults:function () {
        return{
            path:"",
            data:false,
            place: 0
        };
    },

    initialize:function () {

    },
    //this is a server render, different from a view render
    render:function () {
        var problem = this;
        var requestObject = {
            set: this.get('path'),
            problemSource: this.get('path'),
            xml_command: "renderProblem"
        };
        _.defaults(requestObject, webwork.requestObject);


        if (!problem.get('data')) {
            //if we haven't gotten this problem yet, ask for it
            $.post(webwork.webserviceURL, requestObject, function (data) {
                problem.set('data', data);
            });
        }
    },
    clear: function() {
        this.destroy();
    }
});

/**
 *
 * @type {*}
 */
webwork.ProblemList = Backbone.Collection.extend({
    model:webwork.Problem,

    initialize: function(){
        var self = this;
        this.defaultRequestObject = {

        };
        _.defaults(this.defaultRequestObject, webwork.requestObject);

        if(this.addProblem && this.removeProblem){
            this.on('add', this.addProblem, this);
            this.on('remove', this.removeProblem, this);
        }
        this.syncing = false;
        this.on('syncing', function(value){self.syncing = value});
    },

    comparator: function(problem) {
        return problem.get("place");
    },

    //maybe move to problem list as fetch (with a set name argument)
    fetch:function () {
        var self = this;

        //command needs to be set in the higher model since there are several versions of problem lists

        var requestObject = {};
        _.defaults(requestObject, this.defaultRequestObject);
        self.trigger('syncing', true);
        $.post(webwork.webserviceURL, requestObject,
            function (data) {

                var response = $.parseJSON(data);

                var problems = response.result_data;

                var newProblems = new Array();
                for (var i = 0; i < problems.length; i++) {
                    if (problems[i] != "") {
                        newProblems.push({path:problems[i], place:i});
                    }
                }
                self.reset(newProblems);
                //self.trigger('sync');
                self.trigger('syncing', false);
            }
        );
    }
});

/**
 *
 * @type {*}
 */
webwork.Set = Backbone.Model.extend({
    defaults:{
        name:"defaultSet"
    },

    initialize:function () {
        this.set('problems', new webwork.ProblemList);
        //this.get('problems').url = this.get('name');
        _.extend(this.get('problems').defaultRequestObject, {
            set: this.get('name'),
            xml_command: "listSetProblems"
        });

        this.get('problems').fetch();
    }

});

/**
 *
 * @type {*}
 */
webwork.SetList = Backbone.Collection.extend({
    model:webwork.Set,

    initialize: function(){
        var self = this;
        this.defaultRequestObject = {};

        _.defaults(this.defaultRequestObject, webwork.requestObject);
        this.syncing = false;
        this.on('syncing', function(value){self.syncing = value});
    },

    fetch:function () {
        var self = this;

        var requestObject = {
            xml_command: "listSets"
        };
        _.defaults(requestObject, this.defaultRequestObject);
        self.trigger('syncing', true);
        $.post(webwork.webserviceURL, requestObject, function (data) {
            var response = $.parseJSON(data);

            var setNames = response.result_data;
            setNames.sort();

            var newSets = new Array();
            for (var i = 0; i < setNames.length; i++) {
                //workAroundSetList.renderList(workAroundSetList.setNames[i]);
                newSets.push({name:setNames[i]})
            }
            self.reset(newSets);
            self.trigger('syncing', false);
        });
    }
});

