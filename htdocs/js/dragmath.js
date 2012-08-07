var thedata;
var newwin;
var thenumber;
function dragmathedit(textarea)
{
    thenumber = textarea;
    theform = 'problemMainForm';
    thedata = document.forms[theform].elements[textarea].value;
    newwin = window.open("/webwork2_files/dragmathedit/webwork-popup.html","","width=600,height=450,resizable");
}

