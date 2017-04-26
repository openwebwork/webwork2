function updateMathQues() {
    var TeX = document.getElementById("question").value;
    MathJax.Hub.Queue(["Typeset",MathJax.Hub,TeX]);
}
function updateMathChoices() {
    var TeXChoice1 = document.getElementById("optionOne").value;
    MathJax.Hub.Queue(["Typeset",MathJax.Hub,TeXChoice1]);
    var TeXChoice2 = document.getElementById("optionTwo").value;
    MathJax.Hub.Queue(["Typeset",MathJax.Hub,TeXChoice2]);
    var TeXChoice3 = document.getElementById("optionThree").value;
    MathJax.Hub.Queue(["Typeset",MathJax.Hub,TeXChoice3]);
    var TeXChoice4 = document.getElementById("optionFour").value;
    MathJax.Hub.Queue(["Typeset",MathJax.Hub,TeXChoice4]);
    var TeXChoice5 = document.getElementById("optionFive").value;
    MathJax.Hub.Queue(["Typeset",MathJax.Hub,TeXChoice5]);
}
function updateMathHint() {
    var TeX2 = document.getElementById("solution").value;
    MathJax.Hub.Queue(["Typeset",MathJax.Hub,TeX2]);
}
/* sendquestion sends the question entered by the user to the backend */ 

function sendQuestion() 
	{
		var question = document.getElementById("question").value; 
		if(question == "") 
		{
			alert("Ooops! You left the question blank. Please try again"); 
		} 
		var output = document.getElementById("outputQues"); 
		output.innerHTML = "You asked : " +question; 
	}

/* sendAnswer sends the answer entered by the user to the backend */ 
	
	function sendAns()
	{
	
		var answer = ""; 
	if(document.getElementById("one").checked)
	{
		var answer = document.getElementById("optionOne").value; 
  	}
	else if(document.getElementById("two").checked)
	{
		 var answer = document.getElementById("optionTwo").value; 
  	}
	else if(document.getElementById("three").checked)
	{
	 var answer = document.getElementById("optionThree").value; 
  	}
	else if(document.getElementById("four").checked)
	{
	 var answer = document.getElementById("optionFour").value; 
  	}
	
 else if(document.getElementById("five").checked)
	{
	 var answer = document.getElementById("optionFive").value; 
	}
	else
	{ 
		alert("Please select an answer"); 
	}
	
		var output = document.getElementById("outputAns");  
		output.innerHTML = "You answered : " +answer; 	

	}
	/* sendSolution sends the solution/hint entered by the user to the backend */ 
        function sendSolution() 
	{
		var solution = document.getElementById("solution").value; 
		var output = document.getElementById("outputSolution"); 
		output.innerHTML = "Your solution is : "  +solution; 
	}  

/* myFunction1 creates an array of the options entered by the user*/ 
	function myFunction1() 
	{
	var coptionArray = new Array();
		coptionArray[0] = document.getElementById("optionOne").value;
		coptionArray[1] = document.getElementById("optionTwo").value; 
		coptionArray[2] = document.getElementById("optionThree").value; 
		coptionArray[3] = document.getElementById("optionFour").value; 
		coptionArray[4] = document.getElementById("optionFive").value; 

		var question = document.getElementById("question").value;

		if(coptionArray[0] == "") 
		{
			alert("Ooops! You left the first block blank. Please try again"); 
		} 
		var output = document.getElementById("option1"); 
		var outputString = "Your options are " + coptionArray[0];
		
		if(coptionArray[1] != "")
		{
			outputString = outputString.concat(", " + coptionArray[1]);
		}
		if(coptionArray[2] != "")
		{
			outputString = outputString.concat(", " + coptionArray[2]);
		}
		if(coptionArray[3] != "")
		{
			outputString = outputString.concat(", " + coptionArray[3]);
		}
		if(coptionArray[4] != "")
		{
			outputString = outputString.concat(", " + coptionArray[4]);
		}	
		output.innerHTML = "" + outputString;
	}
	
/*generatePerl generates the perl that is supposed to be integrated in webwork */ 
	function generatePerl()
	{		
		var option1 = document.getElementById("optionOne").value;
		var option2 = document.getElementById("optionTwo").value;	
		var option3 = document.getElementById("optionThree").value;
		var option4 = document.getElementById("optionFour").value;
		var option5 = document.getElementById("optionFive").value;

		var optionArray = new Array;
		if(option1 != ""){
			optionArray[0] = '"' + option1 + '"';}
		if(option2 != ""){
			optionArray[1] = '"' + option2 + '"';}
		if(option3 != ""){
			optionArray[2] = '"' + option3 + '"';}
		if(option4 != ""){
			optionArray[3] = '"' + option4 + '"';}
		if(option5 != ""){
			optionArray[4] = '"' + option5 + '"';}
		
		
		var question = document.getElementById("question").value;			

		var characterCount1 = (question.match(/$$/g) || []).length;
		for(i = 0; i <= characterCount1; i++)
		{	
			if(i%2 == 0)
				question = question.replace("$$","<br><br>[`\\");
			else
				question = question.replace("$$","`]<br><br>");
		}
		
		var characterCount2 = (question.match(/$/g) || []).length;
		for(i = 0; i <= characterCount1; i++)
		{	
			if(i%2 == 0)
				question = question.replace("$","[`\\");
			else
				question = question.replace("$","`]");
		}
		var answer = ""; 
	if(document.getElementById("one").checked)
	{
		var answer = document.getElementById("optionOne").value; 
  	}
	if(document.getElementById("two").checked)
	{
		 var answer = document.getElementById("optionTwo").value; 
  	}
	if(document.getElementById("three").checked)
	{
	 var answer = document.getElementById("optionThree").value; 
  	}
	if(document.getElementById("four").checked)
	{
	 var answer = document.getElementById("optionFour").value; 
  	}
	
	else if(document.getElementById("five").checked)
	{
	 var answer = document.getElementById("optionFive").value; 
	}
		
		/*var answer = document.getElementById("answer").value;*/ 
		var solution = document.getElementById("solution").value;

		var section1 = '<br><br>\
		DOCUMENT();\n<br>\
		\n<br>\
		loadMacros\n<br>\
		(\n<br>\
		"PGstandard.pl",\n<br>\
		"parserRadioButtons.pl",\n<br>\
		"PGML.pl"\n<br>\
		);\n<br>\
		\n<br>\
		$mc = RadioButtons(\n<br>[';

		var section2 = '],\n<br>"';

	    	var section3='");\n<br>\
		\n<br>\
		TEXT(beginproblem());\n<br>\
		\n<br>\
		BEGIN_PGML\n<br>';


		var section4 = "\n<br>\
		\n<br>\
		\n<br>\
		[@$mc->buttons()@]*\n<br>\
		[@'\\ $mc->print_a() \\'@]\n<br>\
		END_PGML\n<br>\
		\n<br>\
		$showPartialCorrectAnswers = 0;\n<br>\
		\n<br>\
		ANS($mc->cmp());\n<br>\
		\n<br>\
		Context()->texStrings;\n<br>\
		\n<br>\
		BEGIN_PGML_SOLUTION;\n<br>\
		SOLUTION\n<br>\
		\n<br>";
	
		var section5 = "\n<br>END_PGML_SOLUTION\n<br>\
		Context()->normalStrings;\n<br>\
		\n<br>\
		ENDDOCUMENT();";
		
		var output = document.getElementById("outputCode");
		output.innerHTML = "All the Perl Code is : "  +section1 + optionArray + section2 + answer + section3 + question + section4 + solution + section5;
	}
