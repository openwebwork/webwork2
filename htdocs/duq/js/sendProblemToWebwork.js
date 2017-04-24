var submitButton = document.getElementById("submitButton");
submitButton.onclick = function() {
    var pgString;
    if (submitButton.classList.contains("truefalse")) {
	pgString = generateTrueFalse();
    }
    else if (submitButton.classList.contains("fillinblanks")) {
	pgString = generateFillInBlanks();
    }
    // Remove line breaks.
    pgString = pgString.replace(/<br>/g, '');
    var paramMap = getURLParams(window.location.href);
    var url = "/webwork2/" + paramMap["courseID"] + "/instructor/pgProblemEditor3/"
	+ paramMap["setID"] + "/" + paramMap["problemID"] + "/?key=" + paramMap["key"]
	+ "&user=" + paramMap["user"] + "&effectiveUser=" + paramMap["effectiveUser"];
    var windowName = "WeBWorK : " + paramMap["courseID"] + " : " + paramMap["setID"]
	+ " : " + paramMap["problemID"] + " : Editor";

    var newWindow = window.open(url, windowName);

    $(newWindow).on("load", function() {
	setCodeMirrorText(newWindow, pgString);
    });
}

function setCodeMirrorText(wnd, pgString) {
    var textArea = wnd.document.getElementById("problemContents");
    // Get a handle to the CodeMirror instance.
    var editor = textArea.nextSibling.CodeMirror;
    var doc = editor.getDoc();
    doc.setValue(pgString);
}

// Returns an object with parameter names as keys and parameter values as values.
function getURLParams(url) {
    var params = url.split('?')[1].split('&');
    var paramMap = {};
    params.forEach(function (elt) {
	var pair = elt.split('='); 
	paramMap[pair[0]] = pair[1];
    });
    return paramMap;
}

function generateTrueFalse()
{
    var question = $("#knowlOutput").text();
    var solution = document.getElementById("solution").value; 
    
    if(document.getElementById("true").checked) 
    {
	var answer = "True"; 
    }
    else if(document.getElementById("false").checked) 
    {
	var answer = "False"; 
    }

    var section1 = "<br><br>\
DOCUMENT();\n<br>\
\n<br>\
loadMacros\n<br>\
(\n<br>\
\"PGstandard.pl\",\n<br>\
\"parserRadioButtons.pl\",\n<br>\
);\n<br>\
TEXT(beginproblem());\n<br>\
\n<br>\
$mc = RadioButtons(\n<br>\
[ \"True\", \"False\"],\n<br>\"";

    var section2="\");\n<br>\
\n<br>\
BEGIN_TEXT\n<br>";


    var section3 = "\n<br>\
$BR\n<br>\
\\{ $mc->buttons() \\}\n<br>\
END_TEXT\n<br>\
\n<br>\
$showPartialCorrectAnswers = 0;\n<br>\
\n<br>\
ANS( $mc->cmp() );\n<br>\
\n<br>\
Context()->texStrings;\n<br>\
SOLUTION(EV3(<<'END_SOLUTION'));\n<br>\
$PAR SOLUTION $PAR\n<br>";
    
    var section4 = "\n<br>END_SOLUTION\n<br>\
Context()->normalStrings;\n<br>\
\n<br>\
ENDDOCUMENT();";

    var pgString = section1 + answer + section2 + question + section3 + solution + section4;
    
    //Insert hint/image PG code, if there is a hint or image
    if(document.getElementById("hintText").value != "" || 
       document.getElementById("imageHintText").value != ""
       || document.getElementById("imageText").value != ""){
	pgString = translateToPG(pgString,
				 document.getElementById("hintText").value, 
				 [document.getElementById("imageHintText").value, document.getElementById("imageHintWidth").value, document.getElementById("imageHintHeight").value], 
				 [document.getElementById("imageText").value, document.getElementById("imageWidth").value, document.getElementById("imageHeight").value]);
    }

    var output = document.getElementById("outputCode");
    output.innerHTML = "All the Perl Code is : "  + pgString;
      
    // Save the state of the form
    saveState();
    return pgString;
}

function generateFillInBlanks()
{
	addKnowlHelper();
	var question = $("#knowlOutput").text();
	var answer = document.getElementById("answer").value;
	var solution = document.getElementById("solution").value;

	var section1 = '<br><br>DOCUMENT();\n<br>\
	\n<br>\
	loadMacros(\n<br>\
	"PGstandard.pl",\n<br>\
	"MathObjects.pl",\n<br>\
	);\n<br>\
	\n<br>\
	TEXT(beginproblem());\n<br>\
	\n<br>\
    	Context()->strings->add("';
    
   	var section2 = '"=>{});\n<br>';
	//$answer = String("';
	var section2_String = '$answer = String("';
	var section2_Real ='$answer = Real("';


	var section3 ='");\n<br>\
	\n<br>\
	Context()->texStrings;\n<br>\
	BEGIN_TEXT\n<br>';
	
	var section4 = "<br>$BR\n<br>\
	$BR\n<br>\
	\\{ ans_rule(20) \\}\n<br>\
	END_TEXT\n<br>\
	Context()->normalStrings;\n<br>\
	\n<br>\
	$showPartialCorrectAnswers = 1;\n<br>\
	\n<br>\
	ANS( $answer-> cmp() );\n<br>\
	\n<br>\
	Context()->texStrings;\n<br>\
	SOLUTION(EV3(<<'END_SOLUTION'));\n<br>\
	$PAR SOLUTION $PAR\n<br>";
	
	var section5 = "\n<br>END_SOLUTION\n<br>\
	Context()->normalStrings;\n<br>\
	\n<br>\
	ENDDOCUMENT();";


	var pgString = section1 + answer + section2 + section2_String + answer + section3 + question + section4 + answer + solution + section5;
//Quan from Team Brandon: 
//I think there is a bug in your code in the line above so I fixed it but not sure. 
//Check it please

	/*Tolerance requires a numeric input.  Currently, the code is always a 		 *string, which is problematic.  Therefore, as long as there is

	 */

	if(usingPGML(pgString)){}

	else{	
		if(getSelectedType() == "none"){
			pgString = section1 + answer + section2 +
				section2_String + answer + section3 +
				question + section4 + solution + section5;
		}	
		else{ 
			pgString = section1 + answer + section2 + section2_Real + answer + section3 + 					question + section4 + solution + section5;
		}
	}
	
	//Insert hint/image PG code, if there is a hint or image
        if(document.getElementById("hintText").value != "" || 
                document.getElementById("imageHintText").value != ""
                        || document.getElementById("imageText").value != ""){
                        pgString = translateToPG(pgString,
                                document.getElementById("hintText").value, 
                                        [document.getElementById("imageHintText").value, document.getElementById("imageHintWidth").value, document.getElementById("imageHintHeight").value], 
                                                [document.getElementById("imageText").value, document.getElementById("imageWidth").value, document.getElementById("imageHeight").value]);
        }

	if(getSelectedType() != "none" && 
		document.getElementById("toleranceText").value != ""){

		pgString = checkPGorPGML(pgString, 
			document.getElementById("toleranceText").value,
			getSelectedType());
	}

    //var output = document.getElementById("codeOutput"); 
    //output.innerHTML = "All the Perl code is : <span id='code'>"  + pgString + "</span>";
	
	// Save the state and make the updates in WebWorK
    saveState();

    return pgString;
}
