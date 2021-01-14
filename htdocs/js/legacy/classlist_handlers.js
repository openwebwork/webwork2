/*This is the Javascript which applies some handlers to various input elements*/

function classlist_add_filter_elements() {
	var filter_select = document.getElementById("filter_select");
	var filter_elements = document.getElementById("filter_elements");
	
	if(filter_select.selectedIndex == 3){
		filter_elements.style.display = "block";
	}
	else{
		filter_elements.style.display = "none";
	}
}

function classlist_add_export_elements() {
	var export_select_target = document.getElementById("export_select_target");
	var export_elements = document.getElementById("export_elements");
	
	if(export_select_target.selectedIndex == 0){
		export_elements.style.display = "block";
	}
	else{
		export_elements.style.display = "none";
	}
}

$(function() {
	var filter_select = document.getElementById("filter_select")
	if (filter_select) {
		filter_select.addEventListener("change", classlist_add_filter_elements);
		classlist_add_filter_elements();
	}
	var export_select_target = document.getElementById("export_select_target");
	if (export_select_target) {
		export_select_target.addEventListener("change", classlist_add_export_elements);
		classlist_add_export_elements();
	}
});
