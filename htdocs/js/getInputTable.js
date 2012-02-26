/*This gets the input table for the XMLRPC call*/

function getInputTable(){
	var problem_viewer = document.getElementById("problem_viewer_form");
	var inputElems = problem_viewer.getElementsByTagName("input");
	
	var inputTable = new Array();
	
	var type,name,value;
	for(i in inputElems){
		type = inputElems[i].getAttribute("type");
		name = inputElems[i].getAttribute("name");
		value = inputElems[i].getAttribute("value");
		if(type == "submit" || type == "button" || type == "reset"){
			continue;
		}
		else{
			inputTable[name] = value;
		}
	}
	
	return inputTable;
}