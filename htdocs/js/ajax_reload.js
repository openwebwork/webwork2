/* This is the javascript that creates the AJAX object and attaches it to the reload button*/
/* Reference: w3schools.com, http://www.w3schools.com/ajax/ajax_examples.asp*/

function ajax_Reload() {
	var xmlhttp;

	if(window.XMLHttpRequest){
		xmlhttp = new XMLHttpRequest();
	}
	else{
		xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
	}
	
	xmlhttp.onreadystatechange=function() {
		if (xmlhttp.readyState==4 && xmlhttp.status==200){
			document.getElementById("problem_viewer_content").innerHTML=xmlhttp.responseText;
		}
	};
	
	var tempEditFileDirectory = document.getElementById("temp_url_id").getAttribute("value");
	alert(location.protocol+"//"+location.host+tempEditFileDirectory+"/temp_body.txt");
	xmlhttp.open("GET", location.protocol+"//"+location.host+tempEditFileDirectory+"/temp_body.txt", true);
	xmlhttp.send();
}

/*This method of adding to the onload event listener is taken from tabber.js, which in turn takes from http://simon.incutio.com/archive/2004/05/26/addLoadEvent*/

// var oldonload; 

// oldonload = window.onload;

// if(typeof window.onload != "function"){
	// window.onload = function() { document.getElementById("reload_button").onclick = ajax_Reload; };
// }
// else{
	// window.onload = function() {
		// oldonload();
		// document.getElementById("reload_button").onclick = ajax_Reload;
	// };
// }