             
/* This is a function that parses a CSV file or a classlist (LST) file and fills an HTML table for viewing.
 * The part of the code that parses the CSV file was found (and is documented well) at http://stackoverflow.com/questions/1293147/javascript-code-to-parse-csv-data
 * 
 */
             
define(['XDate'], function(XDate){
var util = {             
    CSVToHTMLTable: function( strData,headers, strDelimiter ){
        strDelimiter = (strDelimiter || ",");
        
        // First strip out any lines that begin with #.  This is to allow the legacy .lst (classlist) files to be easily imported.  
        
        var lines = strData.split("\n");
        var newData = [];
        var poundPattern = new RegExp("^\\s*#");
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
                arr[ arr.length - 1 ].push( strMatchedValue );
        }

        var str = "<table id='sTable'><thead><td><input  id='selectAllASW' type='checkbox'></input></td>";
        for (var k = 0; k < arr[0].length; k++){
            str += "<td><select class='colHeader' id='col" + k + "'>";
            for (var i=0; i< headers.length; i++){
            str += "<option>" + headers[i] + "</option>";}
            str += "</select></td>";
        }
        str += "</thead><tbody><tr><td colspan='" + (arr[0].length+1) + "' style='padding: 0px;'><div class='inner'><table id='inner-table'><tbody>"
        for (var i in arr){
            str += "<tr id='row" + i + "'><td><input  id='cbrow" + i + "' type='checkbox' class='selRow'></input></td>";
            for (var j in arr[i]){
                str += "<td class='column" + j + "'>" + arr[i][j] + "</td>";
            }
            str += "</tr>"
        }
        str += "</tbody></table></div></td></tr></tbody></table>";
        return str;
     }
}

function parseWWDate(str) {
	// this parses webwork dates in the form MM/DD/YYYY at HH:MM AM/PM TMZ
	var wwDateRE = /(\d?\d)\/(\d?\d)\/(\d{4})\sat\s(\d?\d):(\d\d)([aApP][mM])\s([a-zA-Z]{3})/;
        var parsedDate = wwDateRE.exec(str);
	if (parsedDate) {
            var hours = (/[pP][mM]/.test(parsedDate[6]))? (parseInt(parsedDate[4])-1):(parseInt(parsedDate[4])+11);
		var date = new XDate();
                date.setFullYear(parseInt(parsedDate[3]));
                date.setMonth(parseInt(parsedDate[1])-1);
                date.setDate(parseInt(parsedDate[2]));
                date.setHours(hours);
                date.setMinutes(parseInt(parsedDate[5]));
                
                // Do we need to include the time zone?
                
                return date;
	}
}

XDate.parsers.push(parseWWDate);

return util;

});
