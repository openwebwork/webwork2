/* 
 * color.js
 *
 * for coloring the input elements with the proper color based on whether they are correct or incorrect
 *
 * Originally by ghe3
 * Edited by dpvc 2014-08
 */

function color_inputs(correct,incorrect) {
    var className = {};
    var i, m, inputs, input, name;
    var addClass = function (input,name) {
	if (input) {
	    if (input.className == "") {input.className = name} else {input.className += " "+name}
	}
    };

    for (i = 0, m = correct.length; i < m; i++) {
	addClass(document.getElementById(correct[i]),"correct");
	className[correct[i]] = "correct";
    }
    for (i = 0, m = incorrect.length; i < m; i++) {
	addClass(document.getElementById(incorrect[i]),"incorrect");
	className[incorrect[i]] = "incorrect";
    }
    
    inputs = document.getElementsByTagName("input");
    for (i = 0, m = inputs.length; i < m; i++) {
	input = inputs[i];
	if (!input.hidden && input.name === input.id) {
	    name = input.name.replace(/^(MaTrIx_MuLtIaNsWeR|MaTrIx|MuLtIaNsWeR)_/,"").replace(/(_\d+)+$/,"");
	    if (name !== input.name && className[name]) addClass(input,className[name]);
	}
    }
}
