        /*  This will parse a delimited string into an array of arrays. The default delimiter is the comma, but this
                can be overriden in the second argument.  This code was found (and is documented well) at http://stackoverflow.com/questions/1293147/javascript-code-to-parse-csv-data */
             
var util = {             
    CSVToArray: function( strData, strDelimiter ){
        strDelimiter = (strDelimiter || ",");
        var objPattern = new RegExp(("(\\" + strDelimiter + "|\\r?\\n|\\r|^)(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" +
                        "([^\"\\" + strDelimiter + "\\r\\n]*))"),"gi");

        var arrData = [[]];
        var arrMatches = null;
        while (arrMatches = objPattern.exec( strData )){
                var strMatchedDelimiter = arrMatches[ 1 ];
                if (strMatchedDelimiter.length && (strMatchedDelimiter != strDelimiter)){
                        arrData.push( [] );
                }

                if (arrMatches[ 2 ]){
                        var strMatchedValue = arrMatches[ 2 ].replace(new RegExp( "\"\"", "g" ),"\"");
                } else {
                        var strMatchedValue = arrMatches[ 3 ];
                }
                arrData[ arrData.length - 1 ].push( strMatchedValue );
        }
        return( arrData );
    },
    
    /* This creates an HTML Table from an array.  In addition, the column headers are set from the array headers and each is placed in a popup menu. */
    
    fillHTMLTableFromArray: function (arr,headers)
     {
        var str = "<table id='sTable'><thead><td><input  id='selectAllASW' type='checkbox'></input></td>";
        for (var k = 0; k < arr[0].length; k++){
            str += "<td><select class='colHeader' id='col" + k + "'>";
            for (var i=0; i< headers.length; i++){
            str += "<option>" + headers[i] + "</option>";}
            str += "</select></td>";
        }
        str += "</thead>";
        for (var i in arr){
            str += "<tr id='row" + i + "'><td><input  id='cbrow" + i + "' type='checkbox' class='selRow'></input></td>";
            for (var j in arr[i]){
                str += "<td class='column" + j + "'>" + arr[i][j] + "</td>";
            }
            str += "</tr>"
        }
        str += "</table>";
        return str;
     }
}