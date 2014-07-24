define(['backbone', 'underscore','config','./Problem'], function(Backbone, _, config,Problem){
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

            if(this.problemSet) { // the problem comes from a problem set
                return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.setName 
                + "/problems"; 
            } else if (this.type=="subjects") { // this is a set of problems from a library. 
                var _path = "";
                if (this.path[0]) {_path += "/subjects/" + this.path[0];}
                if (this.path[1]) {_path += "/chapters/" + this.path[1];}
                if (this.path[2]) {_path += "/sections/" + this.path[2];}
                return config.urlPrefix + "Library" + _path + "/problems";
            }  else if (this.type=="directories"){
                return config.urlPrefix+"Library/directories/"+this.path.join("/") +"?course_id=" + config.courseSettings.course_id;
            }  else if (this.type==="textbooks"){
                var title = this.path[0].split(" - ")[0];
                var author = this.path[0].split(" - ")[1];
                var _path = "textbooks/author/" + author + "/title/" + title;
                var j;
                var sNames = ["chapter","section"]; 
                for(j=1;j<this.path.length;j++){
                    if(this.path[j]){
                        _path += "/" + sNames[j-1] + "/" + this.path[j];
                    }
                }
                _path += "/problems";

                console.log(_path)

                return config.urlPrefix+_path; 
            } else if (this.type=="localLibrary"){
                return config.urlPrefix+"courses/" +config.courseSettings.course_id + "/Library/local";
            } else if (this.type=="setDefinition"){
                return config.urlPrefix+"courses/" +config.courseSettings.course_id + "/Library/setDefinition";
            }
        }
    });
    
    return ProblemList;
});
