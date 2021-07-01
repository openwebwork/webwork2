(function () {
	if (CodeMirror) {
		cm = CodeMirror.fromTextArea(
			$("#achievementContents")[0],
			{mode: "PG",
				indentUnit: 4,
				tabMode: "spaces",
				lineNumbers: true,
				extraKeys:
				{Tab: function(cm) {cm.execCommand('insertSoftTab')}},
				highlightSelectionMatches: true,
				matchBrackets: true,

			});
		cm.setSize("100%", 400);
	}
})();
