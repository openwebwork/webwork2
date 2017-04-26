/*
* @author Mike Dudas
*/
function checkDollarSigns(requestedID)
{
	var inputString = document.getElementById(requestedID).value;
	var countSingle = 0;
	var countDouble = 0;
	if(inputString.match(/[\$]{2}/g))//need if to check or else it will throw null error
	{
		countDouble = inputString.match(/[\$]{2}/g).length;
	}
	if(inputString.match(/\$/g))//need if to check or else it will throw null error
	{
		countSingle = inputString.match(/\$/g).length;
		if(countDouble > 0)
		{
			countSingle -= countDouble*2;//removes the counted $$, so sub the counted $$
		}
	}
	
	if(countDouble > 0)//contains $$
	{
		while(countDouble > 0)
		{
			if((countDouble % 2) == 0)//even
			{
				inputString = inputString.replace("$$", "\\[");
				countDouble--;
			}
			else//odd
			{
				inputString = inputString.replace("$$", "\\]");
				countDouble--;
			}
		}
	}
	if(countSingle > 0)//contains $
	{
		while(countSingle > 0)
		{
			if((countSingle % 2) == 0)//even
			{
				inputString = inputString.replace("$", "\\(");
				countSingle--;
			}
			else//odd
			{
				inputString = inputString.replace("$", "\\)");
				countSingle--;
			}
		}
	}
	return inputString;
}