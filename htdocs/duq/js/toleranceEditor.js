
/*
* @author Nicholas Marshman
*/

/*
* These functions are utilized to insert the created tolerance code into the string.
* var pgString = string of all of the PG/PGML code that has been created
* var tolString = the string that needs to be inserted into the pgString
* var type = the type of tolerance it is, aka numeric or percentage.
* var tolerance = the numerical value that was inputed in the html b
*/
function checkPGorPGML(pgString, tolerance, type){
	if(usingPGML(pgString)){
		//Call Phil's Code
		return "hi";
	}
	else{
		return toleranceToPG(pgString,tolerance,type);
	}
}
function toleranceToPGML(pgString, tolerance, type){
	var tolString;
	if(type == "num"){
		tolString= "Context()->flags->set(tolerance =>" + tolerance+ 				   ",tolType => \"absolute\",);";
	}
	else{
		tolString= "Context()->flags->set(tolerance =>" + tolerance+ 				   ",tolType => \"relative\",);";
	}
	var index = findIndex('Context("Numeric");', pgString, 'after');
	return splitAndInsert(pgString, index, pgString.length, tolString);
}
function toleranceToPG(pgString, tolerance, type){
	var tolString;
	if(type == "num"){
		tolString="with(tolType=>'absolute',tolerance =>"+tolerance+")->";
	}
	else{
		tolString="with(tolType=>'relative',tolerance =>"+tolerance+")->";
	}
	var index = findIndex('ANS( $answer->',pgString,'after');
	return splitAndInsert(pgString, index, pgString.length, tolString);
}
