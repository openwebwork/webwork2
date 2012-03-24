/*This contains the Javascripts for the handlers on the hmwk sets page.*/

function hmwksets_add_filter_elements() {
	var filter_select = document.getElementById("filter_select");
	var filter_elements = document.getElementById("filter_elements");
	
	if(filter_select.selectedIndex == 3){
		filter_elements.style.display = "block";
	}
	else{
		filter_elements.style.display = "none";
	}
}

addOnLoadEvent(function() {
	if(document.getElementById("filter_select") != null){
		document.getElementById("filter_select").onchange = hmwksets_add_filter_elements;
	}
});

