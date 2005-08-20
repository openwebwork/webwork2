/*
 *  This file customizes jsMath for use with WeBWorK
 */

if (!jsMath || !jsMath.loaded) {

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
    }

  };

  if (window.noFontMessage) {jsMath.styles['.jsM_Warning'] = "display: none"}
  if (window.missingFontMessage) {jsMath.Font.message = missingFontMessage}

  //  Load actual jsMath code
  jsMath.wwSource();

} else {

  /*
   *  We've been loaded a second time, so we want to do asynchronous
   *  processing instead.
   *
   *  First, mark that we have made the patches, and that we aren't
   *  processing math at the moment.
   *  Save a copy of the original ProcessComplete function,
   *   and replace ProcessComplete with one that does the old
   *   function, then looks for more math to process.  If there
   *   is some, continue processing, otherwise say we are done.
   *
   *  Now make ProcessBeforeShowing check to see if we
   *    are already processing (in which case, we'll keep doing so
   *    until there is no more math), otherwise,
   *    start processing the math.
   */
  if (!jsMath.WW_patched) {
    jsMath.WW_patched = 1;
    jsMath.isProcessing = 0;

    jsMath.OldProcessComplete = jsMath.ProcessComplete;

    jsMath.ProcessComplete = function () {
      jsMath.OldProcessComplete();
      jsMath.element = jsMath.GetMathElements();
      if (jsMath.element.length > 0) {
        window.status = 'Processing Math...';
	setTimeout('jsMath.ProcessElements(0)',jsMath.Browser.delay);
      } else {
        jsMath.isProcessing = 0;
      }
    };

    jsMath.ProcessBeforeShowing = function () {
      if (!jsMath.isProcessing) {
        jsMath.isProcessing = 1;
	jsMath.Process();
      }
    };

  }

}
