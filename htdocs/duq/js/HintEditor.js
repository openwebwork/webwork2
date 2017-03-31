/*
 * @author Phil Hansen
 * @author Nick Marshman
 */
function translateToPG(pgString, rawInput, urlDataArr, imgDataArr){
	/*
	* pgToSaveA gets placed after: TEXT(beginproblem());
	* pgToSaveB gets placed after: BEGIN_TEXT
	* pgToSaveC gets placed before: END_TEXT
	* 
	* Please note that WeBWorK pg problems may be using PGML, in which case...
	* pgToSaveA still gets placed after TEXT(beginproblem());
	* BUTT
	* pgToSaveB/C don't get used. Instead,
	* pgToSaveD gets placed after: BEGIN_PGML
	* pgToSaveE gets placed before: END_PGML
	*/
	
	var urlName = urlDataArr[0];
	var urlWidth = urlDataArr[1];
	var urlHeight = urlDataArr[2];
	
	var imgFileName = imgDataArr[0];
	var imgWidth = imgDataArr[1];
	var imgHeight = imgDataArr[2];

	var counter = 0;

	if(urlWidth){} 
		else {var urlWidth = "500"}
	if(urlHeight){} 
		else {var urlHeight = "500"}
	if(imgWidth){} 
		else {var imgWidth = "500"}
	if(imgHeight){} 
		else {var imgHeight = "500"}

	if(imgFileName) {
		var pgToSaveB = "\\{ image( \""+imgFileName+"\",\n<br> width=>"+imgWidth+", height=>"+imgHeight+", tex_size=>700,\n<br> extra_html_tags=>'alt=\""+imgFileName+"\"' ) \\} $BR";
		var pgToSaveD = "[@ image( \""+imgFileName+"\",\n<br> width=>"+imgWidth+", height=>"+imgHeight+", tex_size=>700,\n<br> extra_html_tags=>'alt=\""+imgFileName+"\"' ) @]*  ";
	}
	else{
		var pgToSaveB = "";
		var pgToSaveD = "";
	}

	if(rawInput){var counter = counter + 1;}
	if(urlName) {var counter = counter + 2;}

	if(counter == 1) {
		var pgToSaveA = "HEADER_TEXT(&lt&ltEOF);" + "\n<br>" +
				"&ltscript language=\"javascript\" type=\"text/javascript\"&gt" + "&lt!-- //" + "\n<br>" +
				"var tempInput = \""+ rawInput +"\";" +
				"function rawToText(words){" +
				"url = \"\";" + "\n<br>" +
				"var opt = \"height=600,width=600,location=no,\" +" +
				"\"menubar=no,status=no,resizable=yes,\" +" +
				"\"scrollbars=no,toolbar=no,\";" + "\n<br>" +
				"newwindow=window.open(url,'examdata_info',opt);" +
				"newdocument=newwindow.document;" +
				"newdocument.write(words);" + "\n<br>" +
				"newdocument.close();" + "}" + "// --&gt" +
				"&lt/script&gt" + "\n<br>EOF";

		var pgToSaveC = "$BR" +	"\\{ htmlLink( \"javascript:rawToText(tempInput)\", \"Need help?\" ) \\}";
		
		var pgToSaveE = "\n<br>" + "[@ htmlLink(\"javascript:rawToText(tempInput)\",\"Need help?\") @]*";
	}

	if(counter == 2) {
		var pgToSaveA = "HEADER_TEXT(&lt&ltEOF);" + "\n<br>" +
				"&ltscript language=\"javascript\" type=\"text/javascript\"&gt" +
				"&lt!-- //" + "\n<br>" +
				"var tempInput = \""+ urlName +"\";" +
				"var uheight = \""+ urlWidth +"\";" +
				"var uwidth = \""+ urlHeight +"\";" + "\n<br>" +
				"function rawToText(words, nerds, birds){" +
				"url = \"\";" +
				"var opt = \"height=600,width=600,location=no,\" +" +
				"\"menubar=no,status=no,resizable=yes,\" +" +
				"\"scrollbars=no,toolbar=no,\";" +
				"newwindow=window.open(url,'examdata_info',opt);" +
				"newdocument=newwindow.document;" + "\n<br>" +
				"var iframe = newdocument.createElement('iframe');" +
				"iframe.src = words;" +
				"iframe.height = nerds;" +
				"iframe.width = birds;" + "\n<br>" +
				"newdocument.body.appendChild(iframe);" +
				"newdocument.close();" + "}" + "// --&gt" +
				"&lt/script&gt" + "\n<br>" + "EOF";

		var pgToSaveC = "$BR" +	"\\{ htmlLink( \"javascript:rawToText(tempInput, uheight, uwidth)\", \"Need help?\" ) \\}";
		
		var pgToSaveE = "\n<br>" + "[@ htmlLink(\"javascript:rawToText(tempInput, uheight, uwidth)\",\"Need help?\") @]*";
	}

	if(counter == 3) {
		var pgToSaveA = "\n<br>HEADER_TEXT(&lt&ltEOF);" + "\n<br>" +
		    		"&ltscript language=\"javascript\" type=\"text/javascript\"&gt" + "&lt!-- //" + "\n<br>" +
	  			"var tempInputA = \""+ rawInput +"\";" + "\n<br>" +
				"var tempInputB = \""+ urlName +"\";" + "\n<br>" +
				"var uheight = \""+ urlWidth +"\";" +
				"var uwidth = \""+ urlHeight +"\";" + "\n<br>" +
				"function rawToText(wordsA, wordsB, nerds, birds){" +
				"url = \"\";" +
				"var opt = \"height=600,width=600,location=no,\" +" + "\n<br>" +
		  	        "\"menubar=no,status=no,resizable=yes,\" +" +
	    			"\"scrollbars=no,toolbar=no,\";" + "\n<br>" +
			        "newwindow=window.open(url,'examdata_info',opt);" +
			        "newdocument=newwindow.document;" + "\n<br>" +
			        "newdocument.writeln('&ltp&gt'+wordsA+'&lt/p&gt');" +
			        "var iframe = newdocument.createElement('iframe');" + "\n<br>" +
			        "iframe.src = wordsB;" + "iframe.height = nerds;" +
			        "iframe.width = birds;" + "\n<br>" +
			        "newdocument.body.appendChild(iframe);" +
			        "newdocument.close();" +  "}" +  "// --&gt" +
				"&lt/script&gt" + "\n<br>" + "EOF";

		var pgToSaveC = "$BR" +	"\\{ htmlLink( \"javascript:rawToText(tempInputA, tempInputB, uheight, uwidth)\", \"Need help?\" ) \\}";

		var pgToSaveE = "\n<br>" + "[@ htmlLink(\"javascript:rawToText(tempInputA, tempInputB, uheight, uwidth)\",\"Need help?\") @]*";
	}

	if(counter == 0) {
		var pgToSaveA = "";
		var pgToSaveC = "";
		var pgToSaveE = "";
	}
	
	return insertHintToPG(pgString, pgToSaveA, pgToSaveB, pgToSaveC, pgToSaveD, pgToSaveE);
}

/*
 * @author Sean McShane
 */
//find index of where to insert the hint
function findIndex(section, pgString, indicator){

	//find index of where section begins
	var sectionIndex = pgString.indexOf(section);

	var insertIndex = -1;

	if(indicator == 'before'){
		insertIndex = sectionIndex - 1;
	}

	else if(indicator == 'after'){
		insertIndex = sectionIndex + section.length;
	}

	//return where to insert hint
	return insertIndex;
	
}

//method to split up text area and insert hint in between
function splitAndInsert(pgString, beginIndex, endIndex, hintStr){
	var beginText = pgString.substr(0, beginIndex);
	var endText = pgString.substr(beginIndex+1, endIndex);

	pgString = beginText + hintStr + endText;
	return pgString;
}

//surrounds hint content with new lines
function surroundWithNewLines(hint){
	return '\n<br>' + hint + '\n<br>';
}

//method to see if problem author is using PGML or Text to create problem
function usingPGML(pgString){
	if(pgString.indexOf('BEGIN_PGML') != -1){
		return true;
	}
	else{
		return false;
	}
}
	
//main method called when wanting to insert a hint to problem code
function insertHintToPG(pgString, hint, textHintA, textHintB, pgmlHintA, pgmlHintB){
	
	hint = surroundWithNewLines(hint);
	pgString = splitAndInsert(pgString, findIndex('TEXT(beginproblem());', pgString, 'after'), pgString.length, hint);
	//figure out if using PGML or TEXT in problem PG code
	if(usingPGML(pgString)){
		pgmlHintA = surroundWithNewLines(pgmlHintA);
		pgmlHintB = surroundWithNewLines(pgmlHintB);

		pgString = splitAndInsert(pgString, findIndex('BEGIN_PGML', pgString, 'after'), pgString.length, pgmlHintA);
		pgString = splitAndInsert(pgString, findIndex('END_PGML', pgString, 'before'), pgString.length, pgmlHintB);
	}

	else{
		textHintA = surroundWithNewLines(textHintA);
		textHintB = surroundWithNewLines(textHintB);

		pgString = splitAndInsert(pgString, findIndex('BEGIN_TEXT', pgString, 'after'), pgString.length, textHintA);
		pgString = splitAndInsert(pgString, findIndex('END_TEXT', pgString, 'before'), pgString.length, textHintB);
		return pgString;
	}

}
