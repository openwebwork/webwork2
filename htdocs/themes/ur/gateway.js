function jumpTo(ref) {  // scrolling javascript function
    if ( ref ) {
        var pn = ref - 1; // we start anchors at 1, not zero
        if ( navigator.appName == "Netscape" && 
             parseFloat(navigator.appVersion) < 5 ) {
            var xpos = document.anchors[pn].x;
            var ypos = document.anchors[pn].y;
        } else {
            var xpos = document.anchors[pn].offsetLeft;
            var ypos = document.anchors[pn].offsetTop;
        }
        if ( window.scrollTo == null ) { // cover for anyone
            window.scroll(xpos,ypos);    //   lacking js1.2
        } else {
            window.scrollTo(xpos,ypos);
        }
    }
    return false; // prevent link from being followed
}

// timer for gateway 
var theTime = -1;      // -1 before we've initialized
var alerted = -1;      // -1 = no alert set; 1 = 1st alert set
                       // this shouldn't really be needed

function runtimer() {
// aesthetically this is displeasing: we're assuming that the 
// ContentGenerator will put the appropriate form elements in that
// page for us to manipulate.  even with error checking, it seems sort
// of odd.
    if ( document.gwtimer == null ) {  // no timer
        return;
    } else {
        var tm = document.gwtimer.gwtime;
        var st = document.gwtimer.gwpagetimeleft.value;

        if ( st == 0 ) {                  // no time limit
            return;
        } else {
            if ( theTime == -1 ) {
                theTime = st;
                tm.value = toMinSec(theTime);
                setTimeout("runtimer()", 1000);  // 1000 ms = 1 sec
            } else if ( theTime == 0 && alerted != 3 ) {
	        alert("* You are out of time! *");
		alerted = 3;
	    } else if ( alerted != 3 ) {
	        theTime--;
                tm.value = toMinSec(theTime);
                setTimeout("runtimer()", 1000);  // 1000 ms = 1 sec
		if ( theTime == 35 && alerted != 2 ) { // time is in seconds
		    alert("* You have only about 30 seconds to complete " +
		          "this assignment.  Press Grade very soon! *\n" +
			  "* The timer stops while this alert box is open. *");
		    alerted = 2;
		    theTime -= 5;
                } else if ( theTime == 75 && alerted != 1) {
		    alert("* You have only about a minute left " +
		          "to complete this assignment! *\n" +
			  "* The timer stops while this alert box is open. *");
                    alerted = 1;
		    theTime -= 5;
                }
            }
        }
    }
}
function toMinSec(t) {
// convert to min:sec
    mn = Math.floor(t/60);
    sc = t - 60*mn;
    if ( mn < 10 && mn > -1 ) {
        mn = "0" + mn;
    }
    if ( sc < 10 ) {
        sc = "0" + sc;
    }
    return mn + ":" + sc;
}
