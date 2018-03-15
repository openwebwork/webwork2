function getElementsByClassName(searchClass) {
    var classElements = new Array();
    var els = document.getElementsByTagName("input");
    var elsLen = els.length;
    var pattern = new RegExp("(^|\\s)"+searchClass+"(\\s|$)");
    for (i = 0, j = 0; i < elsLen; i++) {
	if ( pattern.test(els[i].className) ) {
	    classElements[j] = els[i];
	    j++;
	}
    }
    return classElements;
}

(function () {
    // note: these textareas could be input fields also
    var textareas = getElementsByClassName("codeshard");
    var editors = [];
    for (i=0; i<textareas.length; i++) {
        var ta = textareas[i];
        var ta_cols;
        if (ta.type == "text") {
            ta_cols = ta.size;
        }
        else {
            ta_cols = ta.cols;
        }
        editors[i] = CodeMirror.fromTextArea(textareas[i],
					     {matchBrackets: true,
					      mode: "text/math",
					     });
        // should probably do something cleverer here than assuming 9px chars
        editors[i].getWrapperElement().setAttribute("class", "CodeMirror AnswerField");
    }
})();
