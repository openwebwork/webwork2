/*
    structure styled after Three.js..kind of

    David Gage 2012

    requires backbone.js, underscore.js, and their dependencies
*/

var webwork = webwork || { REVISION: '0' };


webwork.USER = "user-needs-to-be-defined-in-hidden-variable-id=hidden_user";
webwork.COURSE = "course-needs-to-be-defined-in-hidden-variable-id=hidden_courseID";
webwork.SESSIONKEY = "session-key-needs-to-be-defined-in-hidden-variable-id=hidden_key"
webwork.PASSWORD = "who-cares-what-the-password-is";
// request object, I'm naming them assuming there may be different versions
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
webwork.webserviceURL = "";
webwork.alert_template = _.template('<div class="alert <%= classes %> fade in"><a class="close" data-dismiss="alert" href="#">×</a><%= message %></div>');
webwork.alert = function(message, classes){
    console.log('alert');
    //developers have to add a messages div (span, whatever) to the app to see messages
    $('#messages').html(webwork.alert_template({message: message, classes: classes}));
    setTimeout(function(){$(".alert").alert('close')}, 2000);
};

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

webwork.ProblemList = Backbone.Collection.extend({
    model:webwork.Problem,

    initialize: function(){
        this.defaultRequestObject = {

        };
        _.defaults(this.defaultRequestObject, webwork.requestObject);
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

        $.post(webwork.webserviceURL, requestObject,
            function (data) {
                //try {//this is the wrong way to be error checking
                var response = $.parseJSON(data);

                var problems = response.result_data.split(",");

                var newProblems = new Array();
                for (var i = 0; i < problems.length; i++) {
                    if (problems[i] != "") {
                        newProblems.push({path:problems[i], place:i});
                    }
                }
                self.reset(newProblems);
                //document.getElementById(workAroundTheClosure.name + workAroundTheClosure.id).innerHTML = workAroundTheClosure.name + " (" + workAroundTheClosure.problemArray.length + ")";
                /*} catch (err) {
                 showErrorResponse(data);
                 }*/
            }
        );
    }
});

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


        //this.get('problems').on('add', this.addProblem, this);
        //this.get('problems').on('remove', this.removeProblem, this);
        this.get('problems').fetch();
    }

});

webwork.SetList = Backbone.Collection.extend({
    model:webwork.Set,

    initialize: function(){
        this.defaultRequestObject = {};

        _.defaults(this.defaultRequestObject, webwork.requestObject);
    },
    //think it's fetch I want to replace:
    fetch:function () {
        var self = this;

        var requestObject = {
            xml_command: "listSets"
        };
        _.defaults(requestObject, this.defaultRequestObject);
        console.log("starting set list");
        $.post(webwork.webserviceURL, requestObject, function (data) {
            //try {
            var response = $.parseJSON(data);
            console.log("result: " + response.server_response);
            var setNames = response.result_data.split(",");
            setNames.sort();
            console.log("found these sets: " + setNames);
            var newSets = new Array();
            for (var i = 0; i < setNames.length; i++) {
                //workAroundSetList.renderList(workAroundSetList.setNames[i]);
                newSets.push({name:setNames[i]})
            }
            self.reset(newSets);
            /*} catch (err) {
             showErrorResponse(data);
             }*/
        });
    }
});

//set up alerts to close
$().alert();
//Some default ajax stuff we can keep it or not
$(document).ajaxError(function(e, jqxhr, settings, exception) {
    webwork.alert(exception, "alert-error");
});