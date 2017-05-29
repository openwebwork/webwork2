var localize_basepath;
/*var lang = 'fr_CA';*/
var lang;

$.getScript(localize_basepath + lang + ".js", function(){

	  console.log("Script loaded but not necessarily executed.");

});

function maketext(string) {
		
	if (typeof(translate) != 'undefined' && translate[string]) {
  		return translate[string];
  	}
  		return string;
}

function pluralise(singular, plural, n) {
	if (n != 1) return maketext(plural);
	return maketext(singular);
}	
