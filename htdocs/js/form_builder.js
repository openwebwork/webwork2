
/****** submit types ******/
function viewSet(formID, uploadAddress, spinnerName){
  var weAreUpdating = "view_set";
  var activeSpinner = spinnerName;
  //console.log(uploadAddress);
  document.getElementById(activeSpinner).style.display = "inline";
  var wantedElements = ["myset_sets", "local_sets", "mydisplayMode", "user", "key", "effectiveUser", "showHints", "showSolutions"];
  upload(document.getElementById(formID), uploadAddress, wantedElements, null, weAreUpdating, activeSpinner);
}

function viewProblems(inputName ,formID, uploadAddress, spinnerName){
  var weAreUpdating = "view_problems";
  var activeSpinner = spinnerName;
  document.getElementById(activeSpinner).style.display = "inline";
  upload(document.getElementById(formID), uploadAddress, null, inputName, weAreUpdating, activeSpinner);
}

function saveChanges(formID, uploadAddress, spinnerName){
  var weAreUpdating = "";
  var activeSpinner = spinnerName;
  document.getElementById(activeSpinner).style.display = "inline";
  var wantedElements = ["myset_sets", "local_sets", "reorder", "user", "filetrial", "isReordered", "mysetfiletrial", "trial", "deleted", "moved", "effectiveUser", "key", "new_set_name", "library_sets"];
  upload(document.getElementById(formID), uploadAddress, wantedElements, null, weAreUpdating, activeSpinner);
}

function updateLibCategories(formID, uploadAddress, inputName, spinnerName){
  var weAreUpdating = "lib_categories";
  document.getElementById(spinnerName).style.display = "inline";
  var wantedElements =["effectiveUser", "key", "user", "library_is_basic", "library_subjects", "library_chapters", "library_sections", "library_textbook", "library_textchapter", "library_textsection", "library_keywords"];
  upload(document.getElementById(formID), uploadAddress, wantedElements, inputName, weAreUpdating, spinnerName);
}

function changeLibrary(formID, uploadAddress, sender, spinnerName){
  //console.log(sender.id);
  console.log(sender.value);
  var weAreUpdating = "libs";
  document.getElementById(spinnerName).style.display = "inline";
  var wantedElements = ["effectiveUser", "key", "user"];
  upload(document.getElementById(formID), uploadAddress, wantedElements, sender.value, weAreUpdating, spinnerName);
}

function singleAddSubmit(form, uploadAddress, spinnerName){
  var wantedElements = ["myset_sets", "local_sets", "reorder", "user", "filetrial", "isReordered", "mysetfiletrial", "trial", "deleted", "moved", "effectiveUser", "key", "new_set_name", "library_sets"];
  document.getElementById(spinnerName).style.display = "inline";
  upload(form, uploadAddress, wantedElements, null, "", spinnerName);
}

function rerandomize(){

}

function cleardisplay(){

}

/****** end submit types *****/

function upload(form, uploadAddress, wantedElements, inputName, weAreUpdating, activeSpinner) {
  //console.log("uploaded to " + uploadAddress+ " started for form: " + formID);
  //var form = document.getElementById(formID);
	var formElements = form.elements;
  //create a progress bar:

  //style is in main.css can be moved here if nessiasry
  var xhr = new XMLHttpRequest();
  xhr.addEventListener("progress", updateProgress, false);
  xhr.addEventListener("load", function (event) {transferComplete(event, weAreUpdating, activeSpinner);}, false);
  xhr.addEventListener("error", transferFailed, false);
  xhr.addEventListener("abort", transferCanceled, false);

	xhr.open("POST", uploadAddress, true);
	//webkit
	if(!(typeof FormData === "undefined")){
		//var xhr = new XMLHttpRequest();
	  //console.log("FormData exists");
	  //make this more flexable
	  //check if this works in ff4
		var formData = new FormData(); //new FormData(form);//form.getFormData(); //  these work in ff and chrome but safari doesn't play nice yet
		//so we build the formdata by hand
		for(var i = 0; i < formElements.length; i++){
		  //ignore the submits or we'll confuse perl...poor perl
		  if(formElements[i].type != "submit" && formElements[i].name && (formElements[i].type != "checkbox" || formElements[i].checked)){
				if(stringIsInArray(formElements[i].name, wantedElements)){
				  formData.append(formElements[i].name, formElements[i].value);
				}
			}
		}
		switch (weAreUpdating)
		{
			case "view_set":
      break;
      
			case "view_problems":
				formData.append(inputName, 1);
      break;
      
      case "libs":
        formData.append(inputName, 1);
      break;
      
      case "lib_categories":
        formData.append(inputName, 1);
      break;
      
			default:
				formData.append("update", "Update Set");
      break;
		}
		xhr.send(formData);
	}
		//mozilla untill ff4
	else{
		//console.log("FormData doesn't exist");
		//build top of form
		var boundary = '------WebKitFormBoundary' + (new Date).getTime();
		var dashdash = '--';
		var crlf     = '\r\n';
	
		/* Build RFC2388 string. */
		var builder = '';
	
		/* Generate headers. */
		for(var i = 0; i < formElements.length; i++){
		  //ignore the submits or we'll confuse perl...poor perl
		  if(formElements[i].type != "submit" && formElements[i].name && (formElements[i].type != "checkbox" || formElements[i].checked) && stringIsInArray(formElements[i].name, wantedElements)){
		    if(formElements[i].name.indexOf("all_past_list") == -1)
		      //console.log(formElements[i].name);
		    //build each input
		    builder += dashdash;
			  builder += boundary;
			  builder += crlf;  
			  builder += 'Content-Disposition: form-data; name='+formElements[i].name;
			  builder += crlf;
			  builder += crlf;
			  builder += formElements[i].value;
			  builder += crlf;
			}
		}
		switch (weAreUpdating)
		{
			case "view_set":
      break;
      
			case "view_problems":
				builder += dashdash;
			  builder += boundary;
			  builder += crlf;  
			  builder += 'Content-Disposition: form-data; name='+inputName;
			  builder += crlf;
			  builder += crlf;
			  builder += 1;
			  builder += crlf;
      break;
      
      case "libs":
				builder += dashdash;
			  builder += boundary;
			  builder += crlf;  
			  builder += 'Content-Disposition: form-data; name='+inputName;
			  builder += crlf;
			  builder += crlf;
			  builder += 1;
			  builder += crlf;
      break;
      
			default:
				builder += dashdash;
			  builder += boundary;
			  builder += crlf;  
			  builder += 'Content-Disposition: form-data; name='+"update";
			  builder += crlf;
			  builder += crlf;
			  builder += "Update Set";
			  builder += crlf;
      break;
		}
		//build bottom of form
		builder += dashdash;
		builder += boundary;
		builder += dashdash;
		builder += crlf;
		//send form
		//xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
	  xhr.setRequestHeader('content-type', 'multipart/form-data; boundary=' + boundary);
		xhr.send(builder);
	}
	//console.log("uploaded finished");
}

/****** event listeners ******/
// progress on transfers from the server to the client (downloads)
function updateProgress(evt) {
  if (evt.lengthComputable) {
    var percentComplete = evt.loaded / evt.total;
    //console.log("Percent complete: "+precentComplete);
  } else {
    // Unable to compute progress information since the total size is unknown
    //console.log("Loading.. "+ evt.loaded + " out of " + evt.total);
  }
}

function transferComplete(evt, weAreUpdating, activeSpinner) {
  //console.log("recieved response");
  //console.log(weAreUpdating);
  var responseObject = HTMLParser(evt.target.responseText);
  //console.log(responseObject);
  switch (weAreUpdating)
  {
    case "view_set":
      var newSet = getChildById("mysets_problems", responseObject);
      //console.log(newSet);
      if (newSet) {
				document.getElementById("mysets_problems").innerHTML = newSet.innerHTML;
				document.getElementById('problem_counter').innerHTML = document.getElementById('mysets_problems').childNodes.length;
				weAreUpdating = "";
				redoSetup(document.getElementById("mysets_problems"));
				newSet = null;
				gridify(false)
        hasBeenGridded = false;
        gridify(false);
        if(isGridded){
          hasBeenGridded = false;
          fixGrid();
          fixMysetsGrid();
        }
      } else {
				//console.log(responseObject);
        alert("There is an error in the response, see javascript console for details");
      }
      break;
      
    case "view_problems":
        var problems = getChildById("setmaker_library_data", responseObject);
        //console.log(problems);
      if(problems){
        document.getElementById("setmaker_library_data").innerHTML = problems.innerHTML;
        weAreUpdating = "";
        redoSetup(document.getElementById("setmaker_library_problems"));
        problems = null;
        
        gridify(false)
        hasBeenGridded = false;
        gridify(false);
        if(isGridded){
          hasBeenGridded = false;
          fixGrid();
          fixMysetsGrid();
        }
      } else {
        //console.log(responseObject);
        alert("There is an error in the response, see javascript console for details");
			}
      break;
      
    case "lib_categories":
      //console.log("looking for categories");
      //console.log(getInnerElementId(responseObject, "control_panel"));
      var categories = getChildById("library_categories", responseObject);
      if(categories){
        document.getElementById("library_categories").innerHTML = categories.innerHTML;
        weAreUpdating = "";
        //redoSetup(document.getElementById("setmaker_library_problems"));
        categories = null;
      } else {
        //console.log(responseObject);
        alert("There is an error in the response, see javascript console for details");
			}
      break;
    
    case "libs":
      //console.log("looking for categories");
      //console.log(getInnerElementId(responseObject, "control_panel"));
      var categories = getChildById("library_categories", responseObject);
      if(categories){
        document.getElementById("library_categories").innerHTML = categories.innerHTML;
        weAreUpdating = "";
        //redoSetup(document.getElementById("setmaker_library_problems"));
        categories = null;
      } else {
        //console.log(responseObject);
        alert("There is an error in the response, see javascript console for details");
			}
      break;  
    
    default:
      //console.log(responseObject);
      break;
  }
  //update messages:
  var newMessages = getChildByClass("Message", responseObject);
  var currentMessages = document.querySelectorAll(".Message");
  for(var i = 0; i < currentMessages.length; i++){
    currentMessages[i].innerHTML = newMessages.innerHTML;
  }
  responseObject = null;
  if(document.getElementById(activeSpinner)){
    document.getElementById(activeSpinner).style.display = "none";
  }
}

function transferFailed(evt) {
  alert("An error occurred while transferring the file.");
}

function transferCanceled(evt) {
  alert("The transfer has been canceled by the user.");
}
/****** end event listeners ******/

/****** Utility functions ******/
//i worry about uniqueness of id's can the document see the resulting object here, i hope not
//html parser from https://developer.mozilla.org/en/Code_snippets/HTML_to_DOM#Safely_parsing_simple_HTML.c2.a0to_DOM
function HTMLParser(aHTMLString){
  //their version doesn't seem to work
  /*var html = document.implementation.createDocument("http://www.w3.org/1999/xhtml", "html", null),
    body = document.createElementNS("http://www.w3.org/1999/xhtml", "body");
  html.documentElement.appendChild(body);

  body.appendChild(Components.classes["@mozilla.org/feed-unescapehtml;1"]
    .getService(Components.interfaces.nsIScriptableUnescapeHTML)
    .parseFragment(aHTMLString, false, null, body));
  */
  //might not be safe but it works
  var body = document.createElement("div");
  body.innerHTML = aHTMLString;
  //console.log(body);
  return body;
}

//creates a modal window containing object
function modal(object){
  var modalDiv = document.getElementById('modal-div');
  if(modalDiv){
    document.body.removeChild(modalDiv);
  }
  if(object){
    var modalDiv = document.createElement('div');
    //nessisary styles are included in main.css but can be moved to js if needed
    modalDiv.id= 'modal-div';
    modalDiv.appendChild(object);
    document.body.appendChild(modalDiv);
  }
}

function stringIsInArray(string, array){
  //if the array's empty return true (means we don't care)
  if(!array){
    return true;
  }
  for(var i = 0; i < array.length; i++){
    //switch to regex someday
    if(string.indexOf(array[i]) != -1){
      return true;
    } 
  }
  return false;
}

//returns the first instance of a myClass
function getChildByClass(myClass, el){
  var children = el.childNodes;
  var result = false;
  for(var i = 0; i < children.length; i++){
    if(hasClassName(children[i], myClass)){
      //console.log("Found "+children[i].className);
      result = children[i];
      break;
    } else if(children[i].childNodes.length > 0){
      result = getChildByClass(myClass, children[i]);
      if(result){
        break;
      }
    }
  }
  return result;
}

/*function getInnerElementId(parent, id){
  var children = parent.childNodes;
  var result = false;
  for(var i = 0; i < children.length; i++){
    if(children[i].id == id){
      console.log("Found "+children[i].id);
      result = children[i];
      break;
    } else if(children[i].childNodes.length > 0){
      result = getInnerElementId(children[i], id);
      if(result){
        break;
      }
    }
  }
  return result;
}*/
/****** End utility functions ******/
