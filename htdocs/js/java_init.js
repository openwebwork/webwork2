/*This is the file where the proper functions are initialized for the problem applets which use them.*/

function initWW(){
	if (typeof(initializeWWquestion) == 'function') {
		initializeWWquestion();
	}
}

addOnLoadEvent(initWW);