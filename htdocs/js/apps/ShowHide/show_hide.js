/*This Javascript attaches the proper event handler to the "Show/Hide Description" button*/

function show_hide(){
	var description = document.getElementById("site_description");
	if(description.style.display == "none"){
		description.style.display = "block";
	}
	else{
		description.style.display = "none";
	}
}

addOnLoadEvent(function() { document.getElementById("show_hide").onclick = show_hide; });