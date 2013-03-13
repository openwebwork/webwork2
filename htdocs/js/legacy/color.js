/* color.js file, for coloring the input elements with the proper color based on whether they are correct or incorrect 
	By ghe3*/

function color_in() {
	var correct_elem = document.getElementsByName('correct_ids');
	var incorrect_elem = document.getElementsByName('incorrect_ids');
	var length_c = correct_elem.length;
	var length_i = incorrect_elem.length;
	
	for (var i = 0; i<length_c; i++) {
		var id = correct_elem[i].getAttribute('value');
		var input_elem = document.getElementById(id.substr(0, id.indexOf('_')));
		input_elem.style.backgroundColor = '#88FF88';
	}
	
	for (var j = 0; j<length_i; j++) {
		var id = incorrect_elem[j].getAttribute('value');
		var input_elem = document.getElementById(id.substr(0, id.indexOf('_')));
		input_elem.style.backgroundColor = '#FF9494';
	}
}

addOnLoadEvent(color_in);