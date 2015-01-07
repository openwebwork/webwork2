/*This is the javascript which checks the forms for errors on the Hmwksets editor page.*/

function check_form_hmwk_sets() {
	var filter_text = document.getElementById("filter_text");
	var filter_select = document.getElementById("filter_select");
	var filter_err_msg = document.getElementById("filter_err_msg");
	var filter_radio = document.getElementById("filter_id");
	
	if(filter_radio && filter_select && filter_err_msg && filter_text && filter_radio.checked && filter_select.selectedIndex == 3 && filter_text.value == ""){
		filter_err_msg.style.display = "inline";
		return false;
	}
}


addOnLoadEvent(function (){
	document.getElementById("take_action").onclick = check_form_hmwk_sets;
});