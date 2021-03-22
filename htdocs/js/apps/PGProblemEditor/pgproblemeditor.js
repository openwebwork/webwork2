function setNewWindowStatus(action) {
	document.getElementById("newWindow").disabled = action.id.match(/^action[234]$/);
}

window.addEventListener("DOMContentLoaded", function () {
	if (CodeMirror) {
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

	$(document).keydown(function(e){
		if (e.keyCode === 27)
			$('#render-modal').modal('hide');
	});

	$('#render-modal').modal({ keyboard: true, show: false });

	$('#pg_editor_frame_id').on('load', function () {
		$('#pg_editor_frame_id').contents().find('#site-navigation')
			.addClass('hidden-desktop hidden-tablet');
		$('#pg_editor_frame_id').contents().find('#content')
			.removeClass('span10').addClass('span12');
		$("#pg_editor_frame_id").contents().find('#toggle-sidebar')
			.addClass('hidden');
	});

	$('#submit_button_id').on('click', function() {
		// action0 = view
		// action1 = update
		// action2 = new version
		// action3 = append
		// action4 = revert

		var action0 = document.getElementById('action0');
		var action1 = document.getElementById('action1');

		var target = "_self";
		if ((action0 && action0.checked) || (action1 && action1.checked)) {
			if (document.getElementById("newWindow").checked)
				target = "WW_View";
			else target = "pg_editor_frame";
		}

		$("#editor").attr('target', target);

		if ($('#editor').attr('target') == "pg_editor_frame") {
			$('#render-modal').modal('show');
		}
	});
});
