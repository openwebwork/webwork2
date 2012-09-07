(function () {
    texteditor = document.getElementById("code");
    if (texteditor != null) {
	var editor = CodeMirror.fromTextArea(document.getElementById("code"), {
		lineNumbers: true,
		matchBrackets: true,
		mode: "text/pg",
		indentUnit: 8,
		indentWithTabs: true,
		enterMode: "keep",
		tabMode: "shift"
	    });
	editor.getWrapperElement().setAttribute("class", "CodeMirror ProblemEditor");
    }
})();

