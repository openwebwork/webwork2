function addKnowlHelper() {
    var x = document.getElementById("theWord").value;
    var y = document.getElementById("theDef").value;
    addKnowl(x, y);
}
function addKnowl(theWord, theDef) {
    var x = document.getElementById("question").value;

    var word = theWord;
    var definition = theDef;
   
    var knowl1 = '\\\{ knowlLink("';
    var knowl2 = '",value=>';
    var knowl3 = "'";
    var knowl4 = "') \\\}";
    var y = document.getElementById("theWord").value;
    if(y == "") {
        document.getElementById("knowlOutput").innerHTML = x;
    }
    else if(x.search(word) != -1) {
        var wordPosition = x.search(word);
        var wordLength = word.length;
        var wordLastPos = wordPosition + wordLength;
        var finalKnowl = x.slice(0, wordPosition) + 
            knowl1 + word + knowl2 + knowl3 + 
            definition + knowl4 + x.slice(wordLastPos);
        document.getElementById("knowlOutput").innerHTML = finalKnowl;
    }
    else {
        document.getElementById("knowlOutput").innerHTML = x;
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