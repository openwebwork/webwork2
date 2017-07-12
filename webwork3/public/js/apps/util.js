
/* This is a function that parses a CSV file or a classlist (LST) file and fills an HTML table for viewing.
 * The part of the code that parses the CSV file was found (and is documented well) at http://stackoverflow.com/questions/1293147/javascript-code-to-parse-csv-data
 *
 */

define(['underscore','config','models/AssignmentDateList','models/AssignmentDate','moment'], function(_,config,AssignmentDateList,AssignmentDate,moment){
var util = {
    // as of 2015-01-02, this function is no longer used in lieu of a library.  To delete after some testing.
    CSVToHTMLTable: function( strData,headers, strDelimiter ){
        strDelimiter = (strDelimiter || ",");

        // First strip out any lines that begin with #.  This is to allow the legacy .lst (classlist) files to be easily imported.

        var lines = strData.split("\n");
        var newData = [];
        var poundPattern = /^\s*#/;
        _(lines).each(function(line) {if (! (poundPattern.test(line))) {newData.push(line);}});

        var updatedData = newData.join("\n");


        var objPattern = new RegExp(("(\\" + strDelimiter + "|\\r?\\n|\\r|^)(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" +
                        "([^\"\\" + strDelimiter + "\\r\\n]*))"),"gi");
        var arr = [[]];
        var arrMatches = null;
        while (arrMatches = objPattern.exec( updatedData )){
                var strMatchedDelimiter = arrMatches[ 1 ];
                if (strMatchedDelimiter.length && (strMatchedDelimiter != strDelimiter)){
                        arr.push( [] );
                }

                if (arrMatches[ 2 ]){
                        var strMatchedValue = arrMatches[ 2 ].replace(new RegExp( "\"\"", "g" ),"\"");
                } else {
                        var strMatchedValue = arrMatches[ 3 ];
                }
                // the following is a hack in that if the file starts with , then it doesn't read the first line correctly.
                if(arr[0].length===0 && arrMatches.input.indexOf(strDelimiter)===0){
                    arr[arr.length-1].push("");
                }
                arr[ arr.length - 1 ].push( strMatchedValue );
        }

        return arr;
     },
     // this function escapes both commas and double quotes (")
     csvEscape: function(str){
        if(/[\"|,]/.test(str))
        {
            str = str.replace(/\"/g,'""');
            return '"' + str + '"';
        }   else {
            return str;
        }
     },
     readSetDefinitionFile: function(file){
        var self = this;
        var problemSet = {}
            , problems = []
            , lines = file.split("\n")
            , varRegExp = /^(\w+)\s*=\s*([\w\/\s:]*)$/
            , i,j, result;
        _(lines).each(function(line,lineNum){
            var matches = varRegExp.exec(line);
            if(line.match(/^\s*$/)){return;} // skip any blank lines
            if(matches){
                if(matches[1]==="problemList"){
                    for(i=lineNum+1,j=1;i<lines.length;i++,j++){
                        if(! lines[i].match(/^\s*$/)){
                            result = lines[i].split(",");
                            problems.push({source_file: result[0], value: result[1],max_attempts: result[2],
                                problem_id: j});
                        }
                    }
                    problemSet.problems=problems;
                } else {
                    switch(matches[1]){
                        case "openDate":
                            problemSet.open_date = matches[2];
                            break;
                        case "dueDate":
                            problemSet.due_date = matches[2];
                            break;
                        case "answerDate":
                            problemSet.answer_date = matches[2];
                            break;
                        case "paperHeaderFile":
                            problemSet.hardcopy_header = matches[2];
                            break;
                        case "screenHeaderFile":
                            problemSet.set_header = matches[2];
                            break;
                    }
                }
            }
        });

        return problemSet;

        // now process the problemList
    },
    pluckDateSettings: function(settings){
        return settings.chain().map(function(_s) { return [_s.get("var"),_s.get("value")]})
            .object().pick("pg{timeAssignDue}","pg{assignOpenPriorToDue}","pg{answersOpenAfterDueDate}"
                                ,"pg{ansEvalDefaults}{reducedScoringPeriod}").value();
    },

    getInverseBindings: function(bindings){
        return _.object(_(_(bindings).values()).map(function(v) {
            return _(v).isObject() ? v.observe : v ;}),_(bindings).keys())
    },

        // this parses the fields in obj as integers.
    parseAsIntegers: function(obj,fields){
        ifields = _(_(obj).keys()).intersection(fields); // only select the fields in obj.  
        var values = _(obj).chain().pick(ifields).values().map(function(d) {return d?parseInt(d):d;}).value();
        _.extend(obj,_.object(ifields,values));
        return obj;
    },
    // this returns the object for a Backbone.Stickit bindings object.  This is useful for error reporting.
    invBindings: function(bindings){
        var keys = _(bindings).keys()
        var vals = _(bindings).chain().values().map(function(x) { return _.isObject(x)? x.observe : x;}).value();
        return _.object(vals,keys);
    },
    // This travels through all of the assignments and determines the days that assignment dates fall
    buildAssignmentDates: function (problemSets) {
        var assignmentDateList = new AssignmentDateList();
        problemSets.each(function(_set){
            assignmentDateList.add(new AssignmentDate({type: "open", problemSet: _set,
                    date: moment.unix(_set.get("open_date")).format("YYYY-MM-DD")}));
            assignmentDateList.add(new AssignmentDate({type: "due", problemSet: _set,
                    date: moment.unix(_set.get("due_date")).format("YYYY-MM-DD")}));
            assignmentDateList.add(new AssignmentDate({type: "answer", problemSet: _set,
                    date: moment.unix(_set.get("answer_date")).format("YYYY-MM-DD")}));
            if(parseInt(_set.get("reduced_scoring_date"))>0) {
                assignmentDateList.add(new AssignmentDate({type: "reduced-scoring", problemSet: _set,
                    date: moment.unix(_set.get("reduced_scoring_date")).format("YYYY-MM-DD")}) );
            }
        });
        return assignmentDateList;
    },
    changeClass:function(opts){
        if(opts.state){
            opts.els.removeClass(opts.remove_class).addClass(opts.add_class)
        } else {
            opts.els.addClass(opts.remove_class).removeClass(opts.add_class)
        }
    },
}


return util;

});
