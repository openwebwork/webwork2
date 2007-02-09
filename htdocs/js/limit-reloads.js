var wwLimitReloads = {
  shortTime: 200,  // in microseconds.  Reloads faster than this will be flagged
  loadTime: new Date().getTime()
};

window.onbeforeunload = function () {
  var now = new Date().getTime();
  if (now - wwLimitReloads.loadTime < wwLimitReloads.shortTime) {
    wwLimitReloads.loadTime = now;
    return "You seem to be reloading the page very rapidly.\n"
         + "Perhaps something is holding down your F5 key?";

  }
}
