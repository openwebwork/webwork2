/*This is the file where the proper functions are initialized for the problem applets which use them.*/

function initWW(){
	if (typeof(initializeWWquestion) == 'function') {
		initializeWWquestion();
	}
}
console.log("load intWW at line 8 of java_init.js");

window.addEventListener("load", initWW);
