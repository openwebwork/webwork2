(function () {
	if (CodeMirror) {
		cm = CodeMirror.fromTextArea(
			$("#problemContents")[0], {
				mode: "PG",
				indentUnit: 4,
				tabMode: "spaces",
				lineNumbers: true,
				lineWrapping: true,
				extraKeys:
				{Tab: function(cm) {cm.execCommand('insertSoftTab')}},
				highlightSelectionMatches: true,
				matchBrackets: true,

			});
		cm.setSize("100%", 400);
	}

	$(document).keydown(function(e){
		if (e.keyCode === 27) $('#render-modal').modal('hide');
	});

	$('#render-modal').modal({ keyboard: true, show: false });

	var busyIndicator = null;

	$('#pg_editor_frame_id').on('load', function () {
		if (busyIndicator) {
			busyIndicator.remove();
			busyIndicator = null;
		}
		var contents = $('#pg_editor_frame_id').contents();
		if (contents[0].URL == "about:blank") return;
		contents.find("head").append("<style>#site-navigation,#toggle-sidebar,#masthead,#breadcrumb-row,#footer{display:none;}</style>");
		contents.find('#content').removeClass('span10');
		$('#render-modal').modal('show');
	});

	$('#submit_button_id').on('click', function() {
		var actionView = document.getElementById('action_view');
		var actionSave = document.getElementById('action_save');

		var target = "_self";
		if (actionView && actionView.classList.contains('active'))
			target = document.getElementById("newWindowView").checked ? "WW_View" : "pg_editor_frame";
		else if (actionSave && actionSave.classList.contains('active'))
			target = document.getElementById("newWindowSave").checked ? "WW_View" : "pg_editor_frame";

		$("#editor").attr('target', target);

		if (target == "pg_editor_frame") {
			busyIndicator = $('<div class="page-loading-busy-indicator" data-backdrop="static" data-keyboard="false">' +
				'<div class="busy-text"><h2>Loading...</h2></div>' +
				'<div><i class="fas fa-circle-notch fa-spin fa-3x"></i></div>' +
				'</div>');
			$('body').append(busyIndicator);
		}
	});
})();
