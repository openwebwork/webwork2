/***********************************************************
 *
 * Javascript for gateway tests.  
 *
 * This file includes the routines allowing navigation
 * within gateway tests, manages the timer, and posts 
 * alerts when test time is winding up.
 *
 * The code here relies heavily on the existence of form elements 
 * created by GatewayQuiz.pm
 *
 ***********************************************************/

function jumpTo(ref) {  // scrolling javascript function
    if ( ref ) {
        var pn = ref - 1; // we start anchors at 1, not zero
    
	$('html, body').animate({
	    scrollTop: $("#prob"+pn).offset().top
	}, 500);
	$("#prob"+pn).attr('tabIndex',-1).focus();
    }
    return false; // prevent link from being followed
}

// timer for gateway 
var theTimer;		// variable for the timer
var browserTime;	// on load, the time on the client's computer
var serverTime;		// on load, the time on the server
var timeDelta;		// the difference between those
var serverDueTime;	// the time the test is due

function runtimer() {
// function to start the timer, initializing the time variables
    if ( document.getElementById('gwTimer') == null ) {  // no timer
	return;
    } else {
	theTimer = document.getElementById('gwTimer');
	var dateNow = new Date();
	browserTime = Math.round(dateNow.getTime()/1000);
	serverTime = document.gwTimeData.serverTime.value;
	serverDueTime = document.gwTimeData.serverDueTime.value;
	timeDelta = browserTime - serverTime;

	var remainingTime = serverDueTime - browserTime + 1.*timeDelta;

	if ( remainingTime >= 0 ) {
	    theTimer.innerHTML = "Remaining time: " + toMinSec(remainingTime) + " (min:sec)";
	    setTimeout("updateTimer();", 1000);
	    setTimeout("checkAlert();", 1000);
	} else {
	    theTimer.innerHTML = "Remaining time: 0 min";
	}
    }
}

function updateTimer() {
// update the timer 
    var dateNow = new Date();
    browserTime = Math.round(dateNow.getTime()/1000);
    var remainingTime = serverDueTime - browserTime + 1.*timeDelta;
    if ( remainingTime >= 0 ) {
	theTimer.innerHTML = "Remaining time: " + toMinSec(remainingTime) + " (min:sec)";
	setTimeout("updateTimer();", 1000);
    }
}

function checkAlert() { 
// check to see if we should put up a low time alert
    var dateNow = new Date();
    browserTime = Math.round(dateNow.getTime()/1000);
    var timeRemaining = serverDueTime - browserTime + 1.*timeDelta;

    if ( timeRemaining <= 0 ) {
        alert("* You are out of time! *\n" + 
	      "* Press grade now!     *");
    } else if ( timeRemaining <= 45 && timeRemaining > 40 ) {
	alert("* You have less than 45 seconds left! *\n" + 
	      "*      Press Grade very soon!         *");
    } else if ( timeRemaining <= 90 && timeRemaining > 85 ) {
	alert("* You only have less than 90 sec left to complete  *\n" + 
	      "* this assignment. You should finish it very soon! *");
    }
    if ( timeRemaining > 0 ) {
	setTimeout("checkAlert();", 5000);
    }
}

function toMinSec(t) {
// convert to min:sec
    if ( t < 0 ) {     // don't deal with negative times
	t = 0;
    }
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

// Start timer after the DOM is ready
$(setTimeout("runtimer()",500));

// Clear out the achievement model if there is one
$(function() {    
$(window).load(function() { $('#achievementModal').modal('show');
			    setTimeout(function(){$('#achievementModal').modal('hide');},8000);
			  });
})

