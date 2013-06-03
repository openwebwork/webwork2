/* This script handles warnings for pages that require it, such as PGProblemEditor.pm*/

function handle() {
	var allTags = document.getElementsByTagName('*');
	
	var warningDiv;
	for(i in allTags){
		if(allTags[i].getAttribute('class') == "Warnings"){
			warningDiv = allTags[i];
			break;
		}
	}
	
	var codes = warningDiv.getElementsByTagName('code');
	
	for(j in codes){
		if(codes[j].innerHTML == 'The path to the current problem file template is not defined. at /home/ghe3/webwork/pg/lib/PGalias.pm line 149'){
			if(codes.length == 1){
				warningDiv.style.display = "none";
				var prev = warningDiv.previousSibling;
				while(prev){
					if(prev.nodeType == 1){
						prev.style.display = "none";
						break;
					}
					prev = prev.previousSibling;
				}
				break;
			}
			else{
				codes[j].parentNode.style.display = "none";
				break;
			}
		}
	}
}

addOnLoadEvent(handle);