/*
* @author Quan Tong
* @author Jack Zhou
*/
function addKnowlHelper() {
    var x = document.getElementById("theWord").value;
    var y = document.getElementById("theDef").value;
    var z = document.getElementById("question").value;
	z = checkDollarSigns("question");
    var searchWord = document.getElementById("theSearch").value;
    // Add the created knowls to the database for the user and get the search from the database
    postKnowl(x, y, searchWord, z);
    // Remove the previous knowls from the creation fields for edit
    document.getElementById("theWord").value = "";
    document.getElementById("theDef").value = "";
    if(searchWord != "" && x != "")
	document.getElementById("theSearch").value = document.getElementById("theSearch").value + "@";
    document.getElementById("theSearch").value = document.getElementById("theSearch").value + x;
}

// Send a POST request to set the knowl keywords and definitions and additionally return the values
function postKnowl(theWord, theDef, theSearch, theQuestion){
	// The link to send the POST request to
	var hostName = window.location.hostname;
	var postHREF = "http://" + hostName + "/webwork2/knowl/";
	// Build the POST request that WeBWorK makes when a prolem is updated
	var POSTParameters = {
		"search": theSearch,
		"word": theWord,
		"definition": theDef,
		"effectiveUser": getParam("user")
	};
	// Send a POST request which will add the knowls to the database and return the search from the database
	$.getJSON(postHREF, POSTParameters, function(JSONObject){
		var searchDef = "";
		var searchWord = "";
		// Get the values from the search
		for(var propertyName in JSONObject){
			if(searchDef != ""){
				searchDef = searchDef + "@";
				searchWord = searchWord + "@";
			}
			searchWord = searchWord + propertyName;
			searchDef = searchDef + JSONObject[propertyName];
		}
		if(searchWord != ""){
			if(theWord != "")
				theWord = theWord + "@";
			if(theDef != "")
				theDef = theDef + "@";
         		theWord = theWord + searchWord;
         		theDef = theDef + searchDef;
    		}
    		question = addKnowl(theWord, theDef, theQuestion);
		sendToWebwork(question);
	});
}

function addKnowl(theWord, theDef, theQue) {
    //passed as theQue
    // getting copy of the question
    var words = theWord;
    var definitions = theDef;
    var question = theQue;
   
    var knowl1 = '\\\{ knowlLink("';
    var knowl2 = '",value=>';
    var knowl3 = "escapeSolutionHTML(EV3P('";
    var knowl4 = "')), base64=>1) \\\}";
    // could save these into array
    
    var partsW = words.split("@");
    //word will be format as a,b,c
    var numW= partsW.length;
    var partsD = definitions.split("@");
    //var numD= partsD.length;
    var knowlCode = new Array(numW);
    
    var temp = ["#1","#2", "#3", "#4", "#5", "#6", "#7", "#8","#9", "#10"];
 
    if(words != ""){
        for(var i=0;i< numW;i++){
            var word= partsW[i];
	    word = word.replace(/\\/g, "\\\\");
            var definition=partsD[i];
	    definition = definition.replace(/\\/g, "\\\\");
    if(question.search("\\b"+word+"\\b") != -1) {
        //searching for the word
        var wordPosition = question.search("\\b"+word+"\\b");
        var wordLength = word.length;
        var wordLastPos = wordPosition + wordLength;
        //reform the question with knowl inserted
        knowlCode[i]= knowl1 + word + knowl2 + knowl3 +
        definition + knowl4; // save the code first
        
       var tempKnowl = question.slice(0, wordPosition) + temp[i]+question.slice(wordLastPos);
       // sub
       question = tempKnowl;
        
    }
    }
    for(var j=0;j< numW;j++){
        question= question.replace(temp[j], knowlCode[j]);
    }
    
    }
    return question;
    
}
