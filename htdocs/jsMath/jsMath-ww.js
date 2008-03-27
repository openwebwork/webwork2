/*
 *  This file customizes jsMath for use with WeBWorK
 */

if (!window.jsMath || !window.jsMath.loaded) {

  /*
   *  WW customization of jsMath values
   */

  var jsMath = {

    styles: {
      '.math': 'font-family: serif; font-style: normal; color: grey33; font-size: 75%'
    },
    Controls: {cookie: {scale: 133}},
    Parser: {prototype: {macros: {
      setlength:   ['Macro','',2],
      boldsymbol:  ['Macro','{\\bf #1}',1],
      verb:        ['Extension','verb']
    }}},
    Font: {},

    //
    //  Look for jsMath-ww.js file and replace by jsMath.js
    //  Cause the jsMath.js file to be loaded
    //
    wwSource: function () {
      var script = document.getElementsByTagName('SCRIPT');
      var src = script[script.length-1].getAttribute('SRC');
      if (src.match('(^|/)jsMath-ww.js$')) {
        src = src.replace(/jsMath-ww.js$/,'jsMath.js');
	document.write('<SCRIPT SRC="'+src+'"></SCRIPT>');
      }
    },

    wwCount: 0,  // count if called more than once

    wwProcess: function () {
      if (this.wwCount > 1) return;
      if (this.wwCount == 0) {
        //
        // This is the first call to jsMath, so install handler
        //
        if (window.addEventListener) {window.addEventListener("load",jsMath.wwOnLoad,false)}
        else if (window.attachEvent) {window.attachEvent("onload",jsMath.wwOnLoad)}
        else {window.onload = jsMath.wwOnLoad}
        //
        //  Process the page synchronously
        //
        this.wwProcessWW = jsMath.ProcessBeforeShowing;
      } else {
        //
        //  There are multiple calls, so we're in the Library Browser
        //  Process the page asynchronously
        //
        this.wwProcessWW = jsMath.Process;
      }
      this.wwCount++;
    },

    //
    //  The actual onload handler calls whichever of the two
    //  processing commands has been saved
    //
    wwOnLoad: function () {jsMath.wwProcessWW()}

  };

  if (window.noFontMessage) {jsMath.styles['#jsMath_Warning'] = "display: none"}
  if (window.missingFontMessage) {jsMath.Font.message = missingFontMessage}
  if (!window.processDoubleClicks) {jsMath.Click = {CheckDblClick: function () {}}}

  //
  //  Load jsMath.js
  //
  jsMath.wwSource();

  //
  //  Make sure answer boxes are above jsMath output
  //  (avoids deep baselines in jsMath fonts)
  //
  document.write('<STYLE> .problem INPUT, .problem TEXTAREA {position: relative; z-index: 2} </STYLE>');

}
