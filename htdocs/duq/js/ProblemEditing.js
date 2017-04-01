/*
 * @author Brandon Messineo
 * @author Vince Ivy
 */
// Get the parameter in the query string of the URL
function getParam(parameterName){
	var queryStr = window.location.search.substring(1);
	var properties = queryStr.split("&");
	for(var i = 0; i < properties.length; i++){
		var propertyPair = properties[i];
		property = propertyPair.split("=");
		if(property[0] == parameterName){
			if(property.length != 1)
				return property[1];
			else
				return "";
		}
	}
	return "";
}

// Restore the state from the JSON file into the form (This method is called automatically when the page loads)
function restoreState(){
	// Get the JSON filepath by using the same filepath as the pg file, with a different extension
	var myFileURL = getParam("action.save_as.source_file").replace(/\.pg$/g, ".json");
	// Parse the JSON file into a JSON object
	$.getJSON(myFileURL, function(JSONObject){
		// Replace the fields in the form with the ones saved in the JSON object
		for(var elementId in JSONObject){
			var formElement = $("#" + elementId);
			var tagName = $(formElement).prop("tagName");
			var formElementType = formElement.attr("type");
			var formElementValue = JSONObject[elementId];
			// Restore the value of the textarea in HTML form
			if(tagName.toUpperCase() == "TEXTAREA"){
				formElement.val(formElementValue);
			}
			// Restore the value of the input in HTML form
			else{
				// Restore the value of the test input in HTML form
				if(formElementType == "text"){
					formElement.val(formElementValue);
				}
				// Restore the value of the radio button in HTML form
				else if(formElementType == "radio"){
					if(formElementValue == "true")
						formElement.prop("checked", true);
				}
				// Restore the value of the checkbos in HTML form
				else if(formElementType == "checkbox"){
					if(formElementValue == "true")
						formElement.prop("checked", true);
					else
						formElement.prop("checked", false);
				}
			}
		}
	});
}

// Initiate the saving of the state and update the problem by collecting all of the information and sending it to the perl file to save the state (Currently supports saving values for input-text, input-radio, and input-checkbox elements with the class "DuqWorkSave" and belong in the "userInput" container in HTML)
function saveState(){
	// The link to send the POST request to
	var postHREF = "http://" + window.location.hostname + "/webwork2/" + getParam("courseID") +"/instructor/pgProblemEditor3/" + getParam("setID") +"/" + getParam("problemID") + "/";
	// Attach each form value to the JSON string (Which gets encapculated inside of the POST request)
	var JSONString = "";
	var formElements = $("#userInput").find(".DuqWorkSave");
	for(var i = 0; i < formElements.length; i++){
		var formElement = formElements[i];
		var id = $(formElement).attr("id");
		var tagName = $(formElement).prop("tagName");
		var type = $(formElement).attr("type");
		// Save the value of the textarea in HTML form
		if(tagName.toUpperCase() == "TEXTAREA"){
			JSONString += id + "~~" + $(formElement).val() + "``";
		}
		// Save the value of the input in HTML form
		else{
			// Save the value of the text input in HTML form
			if(type == "text")
				JSONString += id + "~~" + $(formElement).attr("value") +"``";
			// Save the value from the radio button in HTML form
			else if(type == "radio")
				JSONString += id + "~~" + formElement.checked + "``"; 
			// Save the value from the checkbox in HTML form
			else if(type == "checkbox")
				JSONString += id + "~~" + formElement.checked + "``";
		}
	}
	// Build the POST request that WeBWorK makes when a prolem is updated
	var POSTParameters = {
		"JSON": JSONString,
		"user": getParam("user"),
		"effectiveUser": getParam("user"),
		"key": getParam("key"),
		"file_type": "problem",
		"problemContents": $("#code").text().replace(/<br>/g, ""),
		"action": "save",
		"action.view.seed": getParam("action.view.seed"),
		"action.view.displayMode": "MathJax",
		"action.save_as.target_file": getParam("action.save_as.target_file"),
		"action.save_as.source_file": getParam("action.save_as.source_file"),
		"action.save_as.file_type": "problem",
		"action.save_as.saveMode": "rename", 
		"action.add_problem.target_set": getParam("action.add_problem.target_set"), 
		"action.add_problem.file_type": "problem",
		"submit": "Take+Action!"
	};
	// Send a POST request with all of the information passed in the query string, this should first update the problem in WeBWorK and then save the state of the form
	$.post(postHREF, POSTParameters, function(data){
	});
}
