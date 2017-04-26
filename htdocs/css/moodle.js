/*
 *  Turn off interface elements that are not needed by Moodle
 */
if (parent.ww) {
  document.write('<STYLE>.moodleIgnore {display:none}</STYLE>');
  /*
   *  This prevents scrollbars from appearing
   *  (we won't need them because we resize the IFRAME
   *  to fit, but some browsers would show them anyway).
   *
   *  This is not part of the CSS style so that it only
   *  is in effect if JavaScript is enabled.
   */
  if (document.body) {document.body.style.overflow = "hidden"}
}

ww = {
  /*
   *  Look for the "up" image on the Sets page and disable it.
   *  (If WW taged these with ID's, this would be easier.)
   */
  disableUp: function () {
    var img = document.getElementsByTagName('img');
    for (var i=0; i < img.length; i++) {
      if (img[i].src.match(/navUp\.gif$/)) {
        img[i].parentNode.style.display = "none";
	break;
      }
    }
  },

  /*
   *  Look for the "Sets" box and disable it.
   *  (If WW taged these with ID's, this would be easier.)
   */
  disableSets: function () {
    var h2 = document.getElementsByTagName('h2');
    for (var i=0; i < h2.length; i++) {
      if (h2[i].innerHTML == 'Sets') {
        h2[i].parentNode.style.display = "none";
	break;
      }
    }
  },

  /*
   *  This resets the size of the IFRAME to match the
   *  size of the DIV with ID="fullPage", which should be the
   *  whole document.
   */
  updateSize: function () {
    parent.ww.page.height = ww.page.offsetHeight+20;
    parent.ww.page.style.height = "";
  },

  /*
   *  We wait for the window to completely update, then
   *  resize the IFRAME.  Safari has a bug where it gets
   *  the size wrong when the page is reloaded, so we
   *  resize again after a short delay.  Resizing also is
   *  done if the browser window size changes.
   */
  onload: function () {
    if (ww.oldLoad) ww.oldLoad();
    ww.updateSize();
    setTimeout('ww.updateSize()',1); // for reloading in Safari
    setTimeout('window.onresize=ww.updateSize',100); // let it update first
  },

  /*
   *  Save the old onload handler and replace it with ours
   */  
  Init: function () {
    if (!parent.ww || !parent.ww.page) return;
    ww.page = document.getElementById('fullPage');
    if (!ww.page) return;
    ww.oldLoad = window.onload;
    window.onload = ww.onload;
    ww.disableUp();
    ww.disableSets();
  }
}
