$(function () {

    var codeMirrorDefined = true;

    try { CodeMirror; }

    catch (e) {

	if (e.name == "ReferenceError") {
	    codeMirrorDefined = false;
	}
    }
    
    if (codeMirrorDefined) {
	cm = CodeMirror.fromTextArea(
	    $("#problemContents")[0],
	    {mode: "PG",
	     indentUnit: 4,
	     tabMode: "spaces",
             lineNumbers: true,
	     lineWrapping: true,
             extraKeys:
             {Tab: function(cm) {cm.execCommand('insertSoftTab')}},
	     highlightSelectionMatches: true,
	     matchBrackets: true,
	     
	    });
	cm.setSize(700,400);
    }
    
});
