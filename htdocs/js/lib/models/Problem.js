define(['Backbone', 'underscore', 'config'], function(Backbone, _, config){
    /**
     *
     * This defines a single webwork Problem.
     * 
     * @type {*}
     */
    var Problem = Backbone.Model.extend({
        defaults:{  source_file:"",
                data: null,
                problem_id: 0,
                value: 1,
                displayMode: "MathJax",
                problem_seed: 1
        },
        url: function () {
            // need to determine if this is a problem in a problem set or a problem from a library browser
            if(this.collection.setName) { // the problem comes from a problem set
                return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.collection.setName 
                + "/problems/" + this.get("problem_id");
            } else {
                return config.urlPrefix;
            }

        },
        parse: function(response){
            this.id = response? response.source_file : this.get("source_file");
            //this.id = md5(response? response.source_file : this.get("source_file"));
            return response;
        },
        loadHTML: function (success) {
            if (this.collection.setName){  // the problem is part of a set
                $.get( config.urlPrefix + "renderer/courses/"+ config.courseSettings.course_id + "/sets/" 
                    + this.collection.setName 
                    + "/problems/" + this.get("problem_id"),this.attributes, success);
            } else {  // it is being rendered from the library
                $.get(config.urlPrefix + "renderer/problems/0",this.attributes,success);
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