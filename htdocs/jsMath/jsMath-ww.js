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
      lt:          ['Macro','<'],
      gt:          ['Macro','>'],
      setlength:   ['Macro','',2],
      boldsymbol:  ['Macro','{\\bf #1}',1]
    }}},
    Font: {},

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
      var onload = (this.wwCount? this.wwProcessMultiple: this.wwProcessSingle);
      if (window.addEventListener) {window.addEventListener("load",onload,false)}
      else if (window.attachEvent) {window.attachEvent("onload",onload)}
      else {window.onload = onload}
      this.wwCount++;
    },

    wwProcessSingle:   function () {jsMath.ProcessBeforeShowing()},
    wwProcessMultiple: function () {jsMath.Process()}

  };

  if (window.noFontMessage) {jsMath.styles['#jsMath_Warning'] = "display: none"}
  if (window.missingFontMessage) {jsMath.Font.message = missingFontMessage}
  if (!window.processDoubleClicks) {jsMath.Click = {CheckDblClick: function () {}}}

  //  Load actual jsMath code
  jsMath.wwSource();

  //
  //  Make sure answer boxes are above jsMath output (avoids deep
  //  baselines in jsMath fonts)
  //
  document.write('<STYLE> .problem INPUT, .problem TEXTAREA {position: relative; z-index: 2} </STYLE>');

}
