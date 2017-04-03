function addKnowlHelper() {
    var x = document.getElementById("theWord").value;
    var y = document.getElementById("theDef").value;
    var z = document.getElementById("question").value;
    addKnowl(x, y, z);
}

function addKnowl(theWord, theDef, theQue) {
    //passed as theQue
    // getting copy of the question
    var words = theWord;
    var definitions = theDef;
    var question = theQue;
   
    var knowl1 = '\\\{ knowlLink("';
    var knowl2 = '",value=>';
    var knowl3 = "'";
    var knowl4 = "') \\\}";
    // could save these into array
    
    var partsW = words.split("^");  //
    //word will be format as a,b,c
    var numW= partsW.length;
    var partsD = definitions.split("^");
    //var numD= partsD.length;
    var knowlCode = new Array(numW);
    
    var temp = ["#1","#2", "#3", "#4", "#5", "#6", "#7", "#8","#9", "#10"];
    
    if(words == "") {
        document.getElementById("knowlOutput").innerHTML = question;
    }
    
    else{
        for(var i=0;i< numW;i++){
            var word= partsW[i];
            var definition=partsD[i];
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
        //document.getElementById("knowlOutput").innerHTML = finalKnowl;
        // replace knowlOutput for changing perl file
    }
    else {
        document.getElementById("knowlOutput").innerHTML = question;
    }
    }
    for(var j=0;j< numW;j++){
        question= question.replace(temp[j], knowlCode[j]);
    }
        document.getElementById("knowlOutput").innerHTML = question;
    
    }
    
}

//function addNewKnowl() {
//  var div = document.createElement ('div');
  //div.addAttribute();
//        div.innerHTML = 'Knowl keyword <br>' +
//        '<input id="theWord" type="text" name="knowlwords" ><br>' +
//        'Knowl Content:'+ '<br>'
//        + '<textarea id="theDef" rows="4" cols= "50">'
//        + '</textarea><br>';
//        document.getElementById("knowlButton").appendChild(div);
//	
//  }
//doesn't work
