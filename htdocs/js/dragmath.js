var thedata;
var newwin;
var thenumber;
var ourform;
function dragmathedit(textarea)
{
    thenumber = textarea;
    if (document.forms.length == 1){
        ourform = 0;
    } else {
        for (i=0; i < document.forms.length; i++){
            if (document.forms[i].name == 'problemMainForm'){
                 ourform = i;
            }
            if (document.forms[i].name == 'gwquiz'){
                 ourform = i;
            }
        }
    }
    theform = ourform;
    thedata = document.forms[theform].elements[textarea].value;
    newwin = window.open("/webwork2_files/dragmathedit/webwork-popup.html","","width=600,height=450,resizable");
}

