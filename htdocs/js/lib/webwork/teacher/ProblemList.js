define(['Backbone', 'underscore','config', '../ProblemList'], function(Backbone, _, config, ProblemList){
    //Problem admin functions
    
    /**
     *
     * @param problem
     */
    ProblemList.prototype.addProblem = function (problem) {
        //this.add(problem);
        var self = this;
    
        var requestObject = {
            xml_command: "addProblem",
            problemPath: problem.get('path')
        };
        _.defaults(requestObject, this.defaultRequestObject);
    
        $.post(config.webserviceURL, requestObject, function (data) {
            //try {
            var response = $.parseJSON(data);
            // still have to test for success..everywhere
            if (undoing) {// might be a better way to do this later
                redo_stack.push(function () {
                    self.removeProblem(problem);
                });
                undoing = false;
            } else {
                undo_stack.push(function () {
                    self.removeProblem(problem);
                });
            }
            self.trigger('alert', response.server_response);
            self.trigger('sync');
        });
    };
    
    /**
     *
     * @param problem
     */
    ProblemList.prototype.removeProblem = function (problem) {
    
        var self = this;
    
        var requestObject = {
            xml_command: "deleteProblem",
            problemPath: problem.get("path") //notice the difference from create
        };
        _.defaults(requestObject, this.defaultRequestObject);
    
        $.post(config.webserviceURL, requestObject, function (data) {
            //try {
            var response = $.parseJSON(data);
            // still have to test for success....
            if (undoing) {
                redo_stack.push(function () {
                    self.addProblem(problem);
                });
                undoing = false;
            } else {
                undo_stack.push(function () {
                    self.addProblem(problem);
                });
            }
            self.trigger('alert', response.server_response);
            self.trigger('sync');
        });
        //problem.destroy();
    };
    
    /**
     *
     */
    ProblemList.prototype.reorder = function(){
        var self = this;
        self.sort();
    
        var probList = self.pluck("path");
        var probListString = probList.join(",");
        console.log(probListString);
        var requestObject = {
            probList: probListString,
            xml_command: "reorderProblems"
        };
    
        _.defaults(requestObject, this.defaultRequestObject);
        console.log(requestObject.set);
    
        $.post(config.webserviceURL, requestObject, function (data) {
            //try {
            var response = $.parseJSON(data);
            console.log("result: " + response.server_response);
            self.trigger('alert', response.server_response);
            self.trigger('sync');
        });
    };
    
    return ProblemList;
});