/*This defines a function which removes duplicate javascript files from the page*/

function removeDuplicates(){
	var scripts = document.getElementsByTagName("script");

	var src;
	var i,j,x
	for(i=0; i<scripts.length; i++){
		src = scripts[i].getAttribute("src");
		if(src != null){
			for(j=0; j<scripts.length; j++){
				if(scripts[j].getAttribute("src") == src && j != i){
					scripts[j].parentNode.removeChild(scripts[j]);
				}
			}
		}
	}
}

addOnLoadEvent(removeDuplicates);