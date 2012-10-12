/*
 * The core model for a ProblemSet in Webwork. 
 *
 * */


webwork.ProblemSet = Backbone.Model.extend({
    defaults:{
        set_id: "",
        set_header: "",
        hardcopy_header: "",
        open_date: 0,
        due_date: 0,
        answer_date: 0,
        visible: 0,
        enable_reduced_scoring: 0,
        assignment_type: "",
        attempts_per_version: -1,
        time_interval: 0,
        versions_per_interval: 0,
        version_time_limit: 0,
        version_creation_time: 0,
        problem_randorder: 0,
        version_last_attempt_time: 0,
        problems_per_page: 1,
        hide_score: "N",
        hide_score_by_problem: "N",
        hide_work: "N",
        time_limit_cap: "0",
        restrict_ip: "No",
        relax_restrict_ip: "No",
        restricted_login_proctor: "No",
        visible_to_students: "Yes"
    },
    initialize: function(){
        this.on('change',this.update);
    },

    update: function(){
        
        console.log("in webwork.ProblemSet update");
        var self = this;
        var requestObject = {
            "xml_command": 'updateSetProperties'
        };
        _.extend(requestObject, this.attributes);
        _.defaults(requestObject, webwork.requestObject);

        $.post(webwork.webserviceURL, requestObject, function(data){
            console.log(data);
            var response = $.parseJSON(data);
            var user = response.result_data;
            self.set(user);  // Not sure why this needs to be explicitly called.  

	    self.trigger("success","problem_set_changed",self)
        });
    },
});
    
webwork.ProblemSetList = Backbone.Collection.extend({
    model: webwork.ProblemSet,

    initialize: function(){
        var self = this;
        this.on('add', function(problemSet){
            var self = this;
            var requestObject = {"xml_command": 'addProblemSet'};
            _.extend(requestObject, problemSet.attributes);
            _.defaults(requestObject, webwork.requestObject);
            
            $.post(webwork.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                self.trigger("success","problem_set_added", user);
            });
            
            }, this);
        this.on('remove', function(problemSet){
            var request = {"xml_command": "deleteProblemSet", "problem_set_name" : problemSet.name };
	    _.defaults(request,webwork.requestObject);
            _.extend(request, problemSet.attributes);
            console.log(request);
	    $.post(webwork.webserviceURL,request,function (data) {
                
                console.log(data);
                var response = $.parseJSON(data);
                // see if the deletion was successful. 
    
               self.trigger("success","problem_set_deleted",user);
               return (response.result_data.delete == "success")
            });

            
        }, this);
        
       },

    fetch: function(){
        var self = this;
        var requestObject = {
            "xml_command": 'getSets'
        };
        _.defaults(requestObject, webwork.requestObject);

        $.get(webwork.webserviceURL, requestObject, function(data){
            var response = $.parseJSON(data);
            console.log(response);
            
            var newSet = new Array();
            
            _(response.result_data).each(function(set) {
                newSet.push(new webwork.ProblemSet(set));
                
                });
            self.reset(newSet);
            
//            var problemSets = response.result_data;
            //self.reset(problemSets);
            self.trigger("fetchSuccess");
        });
    }
});

webwork.ProblemPath = Backbone.Model.extend({
    defaults: {
        path: ""
    }
    });

webwork.ProblemSetPathList = Backbone.Collection.extend({
    model: webwork.ProblemPath,
    initialize: function (){
 
        
    },
    
    fetch: function(setName){
                            // Load in the problems.  There has to be a better way to do this.
        var self = this;
        var req = {"xml_command": "listSetProblems", "set": setName};
         _.defaults(req,webwork.requestObject)
        $.get(webwork.webserviceURL,req, function(data) {
            var response = $.parseJSON(data);
            _(response.result_data).each(function(_path) {self.add(new webwork.ProblemPath({path: _path}))});
            self.trigger("fetchSuccess");
        });

    }
});
    
    