/*This is the file where the proper functions are initialized for the problem applets which use them.*/

function initWW(){
	if (typeof(initializeWWquestion) == 'function') {
		initializeWWquestion();
	}
}
console.log("addOnLoadEvent intWW at line 8 of java_init.js");

// this addOnLoad event is in ww_applet_support.js line 740.
addOnLoadEvent(initWW);