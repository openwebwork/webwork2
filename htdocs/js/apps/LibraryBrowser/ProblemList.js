define(['Backbone', 'underscore','config','./Problem'], function(Backbone, _, config,Problem){
    //Problem admin functions
    
    /**
     *   This is a generic list of WeBWorK Problems.  It is used both in the library browser as a list of problems from 
     *   the problem library (or local library) as well as a Problem Set.  
     *   When creating a problem list, one should pass some of the following:
     *   type: either "Library Problems" (for problems from the library) or "Problem Set" (for a problem set)
     *   path: path for a library set
     *   setName: the name of the Problem set  (often the set_id)
     *  
     * @param problem
     */
    var ProblemList = Backbone.Collection.extend({
        model:Problem,
    
        initialize: function(options){
            var self = this;
            _.bindAll(this,"fetch","addProblem","removeProblem");
            _.extend(this,options);
            this.defaultRequestObject = {};
            this.on("remove",this.removeProblem);
            if (this.type){   // this prevents the fetch if the ProblemList comes from the Browse object. 
                this.fetch(); 
            }
        },
        // This keeps the problem set sorted by place in the set.  
        comparator: function(problem) {
            return parseInt(problem.get("place"));
        },  
        fetch: function()
        {
            var self = this;
            var requestObject = {};
            switch(this.type){
                case "Problem Set":
                    console.log("fetching problems for Problem Set " + this.defaultRequestObject.set);
                    requestObject = {xml_command: "listSetProblems", set_id: this.defaultRequestObject.set};
                    break;
                case "Library Problems":
                    var pathParts = this.defaultRequestObject.library_name.split('/');
                    console.log(pathParts);
                    switch(pathParts[1]){
                        case "Library":
                            console.log("Fetching Library: " + this.defaultRequestObject.library_name);
                            requestObject = {  xml_command: "listLib", command: "files",
                                    maxdepth: 0, library_name: this.defaultRequestObject.library_name};
                            break;
                        case "Subjects":
                            console.log("fetching subjects");
                            requestObject = { xml_command: "searchLib", command: "getDBListings",
                                    library_subjects: pathParts[1],
                                    library_chapters: pathParts[2],
                                    library_sections: pathParts[3] }
                            break;
                        }
                    break;
            }
            _.defaults(requestObject, config.requestObject);
            $.get(config.webserviceURL, requestObject,function (data) {
                var response = $.parseJSON(data);
                var problems = response.result_data;
                //console.log('Loading Problems');
                //console.log(response);
    
                var newProblems = new Array();
                for (var i = 0; i < problems.length; i++) {
                    if (problems[i] != "") {
                        newProblems.push(new Problem({path:problems[i],place: i}));
                    }
                } 
                //console.log(self);
                self.reset(newProblems);
                self.trigger("fetchSuccess");
            });

        },

       
    addProblem: function (problem) {
        var self = this;
        console.log("in ProblemList addProblem");
        var requestObject = {
            xml_command: "addProblem",
            set_id: self.setName,
            problemPath: problem.get('path'),
            place: self.size(),
            value: problem.get("value")
        };
        _.defaults(requestObject, config.requestObject);
        $.post(config.webserviceURL, requestObject, function (data) {
            var response = $.parseJSON(data);  // check if there is an error.

            problem.set("place",self.size(),{silent:true});  // put the problem in the last slot of the Problem List
            self.add(problem);
        });
    },
    removeProblem: function (problem) {
        console.log("in ProblemList removeProblem");
        var self = this;
    
        var requestObject = {
            xml_command: "deleteProblem",
            set_id: self.setName,
            problemPath: problem.get("path") //notice the difference from create
        };
        _.defaults(requestObject, config.requestObject);
    
        $.post(config.webserviceURL, requestObject, function (data) {
            var response = $.parseJSON(data);
            console.log("in removeProblem");
            console.log(response);
            self.trigger("deleteProblem",self.setName, parseInt(self.lastProblemRemoved));
        });
        this.lastProblemRemoved = problem.get("place"); // This is a way to save the Problem # deleted. 
        problem.destroy();
    },
    reorder: function(){
        var self = this;
        self.sort();
    
        var probList = self.pluck("path");
        var probListString = probList.join(",");
        console.log(probListString);
        var requestObject = {
            set_id: self.setName,
            probList: probListString,
            xml_command: "reorderProblems"
        };
    
        _.defaults(requestObject, config.requestObject);
    
        $.post(config.webserviceURL, requestObject, function (data) {
            var response = $.parseJSON(data);
            console.log(response);
            self.trigger("reordered");
        });
    }

    });
    
    return ProblemList;
});
