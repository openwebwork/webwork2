//Problem admin functions

/**
 *
 * @param problem
 */
webwork.ProblemList.prototype.addProblem = function (problem) {
    //this.add(problem);
    var self = this;

    var requestObject = {
        xml_command: "addProblem",
        problemPath: problem.get('path')
    };
    _.defaults(requestObject, this.defaultRequestObject);

    $.post(webwork.webserviceURL, requestObject, function (data) {
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
webwork.ProblemList.prototype.removeProblem = function (problem) {

    var self = this;

    var requestObject = {
        xml_command: "deleteProblem",
        problemPath: problem.get("path") //notice the difference from create
    };
    _.defaults(requestObject, this.defaultRequestObject);

    $.post(webwork.webserviceURL, requestObject, function (data) {
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
webwork.ProblemList.prototype.reorder = function(){
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

    $.post(webwork.webserviceURL, requestObject, function (data) {
        //try {
        var response = $.parseJSON(data);
        console.log("result: " + response.server_response);
        self.trigger('alert', response.server_response);
        self.trigger('sync');
    });
};