/*
 * @author Alexander Barnhart
 */
function splitAndInsertModified(pgString, beginIndex, endIndex, hintStr){
	//original author: Sean McShane 
	//modified by: Alexander Barnhart	
	var beginText = pgString.substr(0, beginIndex);
	var endText = pgString.substr(endIndex, pgString.length);

	pgString = beginText + hintStr + endText;
	return pgString;
}

function findRand(PGString)
{
	/* this function will take a pg file in string form and search within
	 * it for all random tags([rand]...[/rand]). the program will put these
	 * into an array-of-arrays called randTags[]. the format will be:
	 * randTags[n] = [startIndex, endIndex, [string1, string2, ... , lastString] ];
	 * this is with the assumption that the tagged string will be in the format:
	 * string1,string2,string3,etc.
	 */
	//the pg file in string form
	//the array to return.
	var randTags = [];
	
	var startIndex = 0;	//used for conditional.
	var index = 0;		//actual pointer to area in string. used for navigation.
	
	var beginString = 0;	//begin substring.
	var endString = 0;	//end substring.

	/* count all the occurences of [rand]...[/rand].
	 * this while loop's structure was adapted from code found on: 
	 * http://stackoverflow.com/questions/16897772/looping-through-string-to-find-multiple-indexes
	*/	
	 
	while((index = PGString.indexOf("[rand]", startIndex)) > -1) {
		beginString = PGString.indexOf("[rand]", startIndex) + 6;
		endString = PGString.indexOf("[/rand]",beginString);
		randTags.push(new Array(beginString, endString, PGString.substring(beginString, endString).split(",")));
		startIndex = endString;
	}
	var recievedArr = [];
	
	//calls another function on each element of the randTags array
		
	for(var i = 0; i < randTags.length; i++)	
	{
		recievedArr.push(translateRand(randTags[i]));
	}
	
	var n = 0;
	startIndex = 0;
	while((index = PGString.indexOf("[rand]", startIndex)) > -1) {
		beginString = PGString.indexOf("[rand]", startIndex);
		endString = PGString.indexOf("[/rand]", beginString) + 7;
		
		var newstring = splitAndInsertModified(PGString, beginString, endString, recievedArr[n]);
		PGString = newstring;
		n++;
		startIndex = 0;
	}
	return PGString;
	
}
	 //author James Murphy 	(Group C)
function translateRand(randTagsIn)
{
    //both min and max are inclusive
    var maxSlot = randTagsIn.length;
    var minSlot = 2;
    addingString1 = "@Input1DArray"+randTagsIn[0]+ "" +randTagsIn[1]+ "(";
    for (i = 0; i < maxSlot-1; i++){
        addingString1 += randTagsIn[i] + ",";    //not sure if it needs qoutes (for strings)
    }
    addingString1 += randTagsIn[maxSlot-1] + ");";
    var addingString2 = "$randNum = random("+minSlot+"," + (maxSlot -1) + ",1);";
    var addingString3 = "$func" +randTagsIn[0]+ "" +randTagsIn[1]+ "Trig = Formula($Input1DArray[$randNum]);";
    var addingString4 = "$func" +randTagsIn[0]+ "" +randTagsIn[1]+ "Deriv = func" +randTagsIn[0]+ "" +randTagsIn[1]+ "Trig->D();";

    return addingString1 +"\n" + addingString2 +"\n" + addingString3 +"\n" +addingString4; //\n should work fine
		//returns 4 lines of PG code for creation of random then returns that
}
