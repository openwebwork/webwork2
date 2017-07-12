define(['backbone', 'underscore', 'config', 'apps/util'], function(Backbone, _, config,util){
    /**
     *
     * This defines a single webwork Problem (Global Problem)
     *
     * @type {*}
     */
    var Problem = Backbone.Model.extend({
        defaults:{
            source_file:"",
            data: "",
            problem_id: 0,
            value: 1,
            max_attempts: -1,
            set_id: "",
            flags: "",
            problem_seed: 1,
            showMeAnotherCount: 0,
            showMeAnother: -1
        },
        integerFields: ["problem_id","value","max_attempts","problem_seed","showMeAnotherCount"],
        validation: {
             // need to put the validation message in a template
            value: {pattern: /^[1-9]\d*$/, msg: "The value must be a positive whole number." },
            max_attempts: {pattern: /^(-1|\d*)$/, msg: "The value must be a whole number or -1 for unlimited attempts." }
        },
        parse: function(response){
              return util.parseAsIntegers(response,this.integerFields);
        },
        idAttribute: "_id",
        url: function () {
            // need to determine if this is a problem in a problem set or a problem from a library browser
            if(typeof(this.collection.problemSet)!=="undefined") { // the problem comes from a problem set
                return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/"
                + this.collection.problemSet.get("set_id") + "/problems/" + this.get("problem_id");
            } else if (this.collection.set_id !=="undefined" && this.collection.user_id !=="undefined"){  // it's a userProblem
                return config.urlPrefix + "courses/" + config.courseSettings.course_id
                    + "/users/" + this.collection.user_id
                    + "/sets/" + this.collection.set_id + "/problems/" + this.get("problem_id");
            } else {
                return config.urlPrefix;
            }

        },
        // override the set function to make sure that integers are parsed:
        set: function(key, val, options) {

          if (typeof key == 'object'){
            obj = key;
          } else {
            obj = {};
            obj[key] = val;
          }
          obj = util.parseAsIntegers(obj,this.integerFields);
          return Backbone.Model.prototype.set.call(this,obj,val,options);
        },
        loadHTML: function (opts) {
            var attrs = {displayMode: opts.displayMode};
            _.extend(attrs,this.attributes);
            if (this.collection && this.collection.setName){  // the problem is part of a set
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
            answers.answer_fields = _.keys(answers).join(";");
            //var allAttributes = {};
            //_.extend(allAttributes,answers);
             $.get( config.urlPrefix + "renderer/courses/"+ config.courseSettings.course_id + "/sets/"
                    + this.collection.set_id + "/problems/" + this.get("problem_id"),answers, success);

        },
        submitAnswers: function(answers,_success){
            answers.answer_fields = _.keys(answers).join(";");
            $.ajax({
                type: "POST",
                url: config.urlPrefix + "renderer/courses/"+ config.courseSettings.course_id + "/sets/"
                    + this.collection.set_id + "/problems/" + this.get("problem_id"),
                    dataType: "json",
                data: answers,
                success: _success});
        }
    });

    return Problem;
});
