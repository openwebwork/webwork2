/*******************************************************
 *
 *  This file implements a JavaScript-based hack to prevent
 *  an autorepeating F5 key from swamping your server with
 *  requests.  it does this by ignoring F5 keydown events
 *  and reloading the page on an F5 keyup event.  It will
 *  also put up a dialog box when it has spotted repeated
 *  F5 attempts to ask you to check if something is sitting
 *  on the F5 button.
 *
 *  This only works in MSIE/PC and Firefox/PC.  It does
 *  not work for Firefox/Mac or Opera (either platform).
 *
 *  Autorepeating the reload button should be considered
 *  a browser bug, in my opinion, but I can't do much
 *  about that.
 *
 *  To install it, add the line
 *
 *    <script src="<!--#url type="webwork" name="htdocs"-->/js/limit-reloads.js"></script>
 *
 *  to the head of the system.template file that you are
 *  using (in a webwork/conf/templates subdirectory).
 *
 ********************************************************/

var wwLimitReloads = {
  maxF5count: 5, // warn after this many blocked F5 attempts
  F5count: 0,
  warned: 0
}

document.onkeydown = function (event) {
  if (!event) {event = window.event}
  if (event.keyCode == 116) {
    if (wwLimitReloads.F5count++ == wwLimitReloads.maxF5count && !wwLimitReloads.warned) {
      wwLimitReloads.warned = 1;
      setTimeout(function () {
        alert("You seem to be generating many F5 presses.\n"
              + "See if something is holding the F5 key down.");
      },10);
    }
    try {event.keyCode = 8} catch (err) {}; // make MSIE event cancelable
    if (event.preventDefault) event.preventDefault();
    if (event.stopPropagation) event.stopPropagation();
    event.cancelBubble = true;
    event.returnValue = false;
    return false;
  }
  return true;
}

document.onkeyup = function (event) {
  if (!event) {event = window.event}
  if (event.keyCode == 116) {window.location.reload()}
}
