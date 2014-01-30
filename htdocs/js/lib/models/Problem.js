define(['Backbone', 'underscore', 'config'], function(Backbone, _, config){
    /**
     *
     * This defines a single webwork Problem (Global Problem)
     * 
     * @type {*}
     */
    var Problem = Backbone.Model.extend({
        defaults:{  source_file:"",
                //data: "",
                problem_id: 0,
                value: 1,
                max_attempts: -1,
                set_id: "",
                flags: ""
                //displayMode: "MathJax",  //this has been commented out.  it should be a property of the problem view, not the problem.
                //problem_seed: 1
        },
        idAttribute: "source_file",
        url: function () {
            // need to determine if this is a problem in a problem set or a problem from a library browser
            if(typeof(this.collection.problemSet)!=="undefined") { // the problem comes from a problem set
                return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" 
                + this.collection.problemSet.get("set_id") + "/problems/" + this.get("problem_id");
            } else {
                return config.urlPrefix;
            }

        },
        loadHTML: function (opts) {
            var attrs = {displayMode: opts.displayMode};
            _.extend(attrs,this.attributes);
            if (this.collection.setName){  // the problem is part of a set
                $.ajax({url: config.urlPrefix + "renderer/courses/"+ config.courseSettings.course_id + "/sets/" 
                    + this.collection.setName + "/problems/" + this.get("problem_id"),
                    data: attrs, success: opts.success,error:opts.error});
            } else {  // it is being rendered from the library
                $.ajax({url:config.urlPrefix + "renderer/courses/"+ config.courseSettings.course_id 
                        + "/problems/0",data:attrs,success:opts.success,error:opts.error});
            }
        },
        loadTags: function (opts) {
            var self = this;
            if(! this.get("tags")){
                var fileID = (this.get("pgfile_id") || -1)
                    , params = (fileID<0)? {source_file: this.get("source_file")} : {};
                $.get(config.urlPrefix + "Library/problems/" + fileID +"/tags",params,function (data) {
                    self.set(data);
                    opts.success(data);
                });
            }
        },
        problemURL: function(){
            // console.log(this.attributes);
            if (this.collection.setName){  // the problem is part of a set
                return config.urlPrefix + "renderer/courses/"+ config.courseSettings.course_id + "/sets/" 
                    + this.collection.setName 
                    + "/problems/" + this.get("problem_id") + "?" + $.param(this.attributes);
            } else {  // it is being rendered from the library
                return config.urlPrefix + "renderer/problems/0?" + $.param(this.attributes);
            }
        },
        checkAnswers: function(answers, success){
            console.log("in checkAnswers");
            var allAttributes = {};
            _.extend(allAttributes,answers);
             $.get( config.urlPrefix + "renderer/courses/"+ config.courseSettings.course + "/sets/" 
                    + this.collection.setName 
                    + "/problems/" + this.get("problem_id"),allAttributes, success);
        }
    });
    
    return Problem;
});