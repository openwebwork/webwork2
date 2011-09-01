/*Here is declared the addOnLoadEvent function, which is used to sequentially add onload event handlers to the page*/

/*This method of adding to the onload event listener is taken from tabber.js, which in turn takes from http://simon.incutio.com/archive/2004/05/26/addLoadEvent*/

function addOnLoadEvent(f) {
	var prevOnload = window.onload;
	
	if(typeof window.onload != 'function'){
		window.onload = function() {
			f();
		}
	}
	else{
		window.onload = function() {
			prevOnload();
			f();
		}
	}
}