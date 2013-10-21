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
    
        // This keeps the problem set sorted by place in the set.  
        comparator: function(problem) {
            return parseInt(problem.get("problem_id"));
        },
        url: function () {

            // need to determine if this is a problem in a problem set or a problem from a library browser

            if(this.setName) { // the problem comes from a problem set
                return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.setName 
                + "/problems"; 
            } else if (this.type=="subjects") { // this is a set of problems from a library. 
                var dirs = this.path.split("/");
                var path = config.urlPrefix + dirs[0];
                if (dirs[1]) {path += "/subjects/" + dirs[1];}
                if (dirs[2]) {path += "/chapters/" + dirs[2];}
                if (dirs[3]) {path += "/sections/" + dirs[3];}
                path+= "/problems";
                return path;
            }  else if (this.type=="directories"){
                return config.urlPrefix+"Library/directories/"+this.path +"?course_id=" + config.courseSettings.course_id;
            }
        },
/*        parse: function(response){
            var self = this;
            return _(response).map(function(_prob){ return (new Problem()).parse(_prob);})
        }, */
        reorder: function(success){
            var self = this;
            //var problemPaths = this.pluck("source_file");
            //var problemIndices = this.pluck("problem_id");
            //var problems = this.map(function(prob) { 
            //        return {source_file: prob.get("source_file"), problem_id: prob.get("problem_id")};});

            $.ajax({  contentType: "application/json", type: "PUT",
                url: config.urlPrefix + "courses/"+ config.courseSettings.course_id + "/sets/" + this.setName + "/problems",
                success: success,
                data: JSON.stringify({problems: self.models}),
                success: success,
                processData: false,
            });
        } 

    });
    
    return ProblemList;
});
