//Start Random Functions- Author: Nicholas Marshman
//Author: Nicholas Marshman

//Used to get the value of the rand tag to be shown
function getTagValue(table){
	var tagNum = 0;
	var numTable = document.getElementById("numTable");
	var trigTable = document.getElementById("trigTable");
	var reOpTable = document.getElementById("reOpTable");

	var valNum = 0;	var trigNum = 0; var reOpNum = 0;

	if(document.getElementById('numValue').checked == true){
		valNum = numTable.rows.length;
	}
	if(document.getElementById('trigValue').checked == true){
		trigNum = trigTable.rows.length;
	}
	if(document.getElementById('reOpValue').checked == true){
		reOpNum = reOpTable.rows.length;
	}

	if(table == "numTable")
		tagNum = valNum;
	else if(table == "trigTable")
		tagNum = valNum + trigNum;
	else if(table == "reOpTable")
		tagNum = valNum + trigNum + reOpNum;

	return tagNum;
}

//Prints out information relating to random numerical values.
/* output = the div field in which the string will be outputted.
 * min = the starting value of their inputted range
 * max = the ending value of their inputted range
 * step = the value they inputted for increments
 */
function sendRandomValue(){
	var output = document.getElementById("randomNumField");
	var min = 0; var max = 0; var step = 0;
	var numTable = document.getElementById("numTable");
	var numCheck = document.getElementById('numValue').checked;	
	
	var outputString = "";
	for(var i = 0; i < numTable.rows.length; i++){
		min = document.getElementsByName("randRangeStart")[i].value;
		max = document.getElementsByName("randRangeEnd")[i].value;
		step = document.getElementsByName("randIncrement")[i].value;
		
		min = min.replace(/^\s+/, '').replace(/\s+$/, '');
		max = max.replace(/^\s+/, '').replace(/\s+$/, '');

		if(numCheck){
			if(min == "" || max == ""){
				alert("Error: You left one of the numerical" 
					+ " value fields blank!");
				break;
			}
			if(min == max){
				alert("Error: You have an equal numerical " 
					+ "range of (" 
					+ min + ", " + max 
					+ "), please fix this!");
				break;
			}
			if(parseInt(min) > parseInt(max)){
				alert("Error: You specified a range where the"
					+ " starting value of " + min 
					+ " is higher than the ending value of " 
					+ max+"!");
				break;
			}
		}
		outputString =outputString.concat("rand"+(i+1)
			+ ": ranges between"+ " (" + min + ", " + max 
			+"), in steps of "+ step + ".<br>"); 
	}
	return "<br>"+outputString;
}
//Prints out information relating to trig and relational operators.
/* output = the div field in which the string will be outputted
 * checkedType = array of strings related to trig or relational ops
 * checked_value = the string that will be outputted when the "enter choice" button is pressed.
 * @param textField = the div field id name
 * @param type = the input names of the checkboxes
 * @param table = the name of the table currently being checked.
 */
function sendRandom(type,table){
	var checkedType = document.getElementsByName(type);
	var tableLength = document.getElementById(table).rows.length-1;
	var checked_value = "";

	var count = 0; var randValue = getTagValue(table)-tableLength;

	for(var i = 0; i < checkedType.length; i++){
		if(count == 0){
			checked_value = checked_value.concat("<br>rand" 
				+ randValue + ": ")
			randValue++;
		}
   		if(checkedType[i].checked){
     		   checked_value = checked_value.concat(" " 
			+ checkedType[i].value);
    		}
		if(count == 5){
			count = 0;
		}
		else{ 
			count++;
		}
	}
	return checked_value;
}
function randNumObjects(x,y,s){
	return {type:"num", min:x,max:y,step:s};
}
function randTrigObjects(i){
	var funcs = document.getElementsByName('trigType');
	
	return {type:"trig",Sin:funcs[i].checked,Cos:funcs[i+1].checked,
		Tan:funcs[i+2].checked,Csc:funcs[i+3].checked,
		Sec:funcs[i+4].checked,Cot:funcs[i+5].checked};

}
function randReOpObjects(i){
	var reops = document.getElementsByName('roType');
	
	return {type:"reOp",less:reops[i].checked,lessEqual:reops[i+1].checked,
		great:reops[i+2].checked,greatEqual:reops[i+3].checked,
		equal:reops[i+4].checked,notEqual:reops[i+5].checked};
	
}
//function meant to create and store all the objects into one array.
function createRandomObjects(pgString){
	var numCheck = document.getElementById('numValue').checked;	
	var trigCheck = document.getElementById('trigValue').checked;
	var reOpCheck = document.getElementById('reOpValue').checked;
	var numTable = document.getElementById("numTable");
	var trigTable = document.getElementById("trigTable");
	var reOpTable = document.getElementById("reOpTable");

	var min; var max; var step;

	var numArray = new Array(); //array of num objects
	var trigArray = new Array(); //array of trig objects
	var reOpArray = new Array(); //array of reOp objects

	/* Num objects consist of three values: Start,End,Increment 
	 * Trig objects and reOp objects consist of booleans relating to
	 * if the checkboxes were checked or not.
	 * Trig: Sin, Cos, Tan, Csc, Sec, Cot
	 * reOp: less,lessEqual,great,greatEqual,equal,notEqual
	 */

	if(numCheck){
	   for(var i = 0; i < numTable.rows.length; i++){
		min = document.getElementsByName("randRangeStart")[i].value;
		max = document.getElementsByName("randRangeEnd")[i].value;
		step = document.getElementsByName("randIncrement")[i].value;

		numArray[i]=randNumObjects(min,max,step);
	   }
	}
	if(trigCheck){
	   var count = 0;
	   for(var i = 0; i < trigTable.rows.length; i++){
		trigArray[i]=randTrigObjects(count);
		count+=6;
	   }	
	}
	if(reOpCheck){
	   var count = 0;
	   for(var i = 0; i < reOpTable.rows.length; i++){
		reOpArray[i]=randReOpObjects(count);
		count+=6;
	   }	
	}

	//Merge arrays into one
	var finalArray = numArray.concat(trigArray.concat(reOpArray));
	
	//Call Derek's function here
	pgString = randParam(finalArray, pgString);
	

	return pgString;
}
//Create the final output in the random box, 
//lists the random variables to be used
function createRandomOutput(){
	//Get the strings from each section
	var numString = sendRandomValue();
	var trigString = sendRandom('trigType','trigTable');
	var reOpString = sendRandom('roType','reOpTable');

	numCheck = document.getElementById('numValue').checked;	
	trigCheck = document.getElementById('trigValue').checked;
	reOpCheck = document.getElementById('reOpValue').checked;

	var output = document.getElementById('randomResults');
	var message = "<br>You created the following variables: <br>";

	//Check to see what boxes they have marked, for the correct output

	if(numCheck)
		message = message.concat(numString);
	if(trigCheck)
		message = message.concat(trigString + "<br>");
	if(reOpCheck)
		message = message.concat(reOpString);

	if(numCheck != true && trigCheck != true && reOpCheck != true)
		alert("You didn't check any boxes.");
	else
		output.innerHTML = message;
}
//If they want randoms, show the next field
function showRandom(){
	document.getElementById('acceptRandoms').style.display='block';
	document.getElementById('finalRandField').style.display='block';
}
//If they remark "no" in the random field, hide all fields.
function hideRandom(){
	document.getElementById('acceptRandoms').style.display='none';
	document.getElementById('randNumValues').style.display='none';
	document.getElementById('randTrig').style.display='none';
	document.getElementById('randRegOp').style.display='none';
	document.getElementById('finalRandField').style.display='none';
}
//Show the num field if checked
function showNumValRand(){
	value = document.getElementById('numValue');	

	if(value.checked == true){
		document.getElementById('randNumValues').style.display='block';
	}
	else{
		document.getElementById('randNumValues').style.display='none';
	}
}
//Show the trig field if checked
function showTrigRand(){
	value = document.getElementById('trigValue');	

	if(value.checked == true){
		document.getElementById('randTrig').style.display='block';
	}
	else{
		document.getElementById('randTrig').style.display='none';
	}
}
//Show the relational operator field if checked
function showReOpRand(){
	value = document.getElementById('reOpValue');

	if(value.checked == true){
		document.getElementById('randRegOp').style.display='block';
	}
	else{
		document.getElementById('randRegOp').style.display='none';
	}
}
//Create a new row by copying the previous.
/* table = the table in which the row is being added
 * row = the row being copied
 * clone = the cloned row
*/
function addNewRow(tableName,row) {
	var table = document.getElementById(tableName);
	var row = document.getElementById(row);
	var clone = row.cloneNode(true); //copy row

	clone.id = "row".concat(table.rows.length); //change id of row 
	table.appendChild(clone); // add new row to end of table

}
//Delete the last created row
function deleteLastRow(name){
	var table = document.getElementById(name);
	if(table.rows.length != 1)
		var row = table.deleteRow(table.rows.length-1);
	//Deleting the first row results in having to refresh the page in order 	to add a new one, therefore the first row can't be deleted.
}
//End Random Section


//insert PG variable inits into pg problem string
function insertRandInits(pgString, initArr){
        for(var i=0; i < initArr.length; i++){
                initArr[i] = initArr[i] + " ";
                if(i == initArr.length-1){
                        initArr[i] = initArr[i] + '<br>';
                }
                pgString = splitAndInsert(pgString, findIndex('TEXT(beginproblem());', pgString, 'before'), pgString.length, '<br>' + initArr[i]);
        }
        return pgString;
}

function escapeRands(answer){
	var rands = answer.match(/\$rand[0-9]+/g);
	if(rands != null){
		for(var i = 0; i < rands.length; i ++){
			answer = answer.replace(rands[i], "'." + rands[i] + ".'");
		}
	}
	return answer;
}
