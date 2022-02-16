(function () {
	if (CodeMirror) {
		cm = CodeMirror.fromTextArea(
			document.getElementById("problemContents"), {
				mode: "PG",
				indentUnit: 4,
				tabMode: "spaces",
				lineNumbers: true,
				lineWrapping: true,
				extraKeys:
				{Tab: function(cm) {cm.execCommand('insertSoftTab')}},
				highlightSelectionMatches: {annotateScrollbar: true},
				matchBrackets: true,
			});
		cm.setSize("100%", 400);
	}

	document.addEventListener('keydown', (e) => {
		if (e.key === 'Escape') bsModal.hide();
	});

	const bsModal = new bootstrap.Modal(document.getElementById('render-modal'), { keyboard: true, show: false });

	let busyIndicator = null;

	const frame = document.getElementById('pg_editor_frame_id');
	frame?.addEventListener('load', () => {
		if (busyIndicator) {
			busyIndicator.remove();
			busyIndicator = null;
		}
		if (frame.contentDocument.URL == 'about:blank') return;
		const style = frame.contentDocument.createElement('style');
		style.type = 'text/css';
		style.textContent = '#site-navigation,#toggle-sidebar,#masthead,#breadcrumb-row,' +
			'#footer,.sticky-nav{display:none !important;}';
		frame.contentDocument.head.appendChild(style);
		frame.contentDocument.getElementById('content').classList.remove('col-md-10');
		frame.contentWindow.addEventListener('resize',
			() => frame.contentDocument.getElementById('content').classList.remove('col-md-10')
		);
		bsModal.show();
	});

	document.getElementById('submit_button_id')?.addEventListener('click', () => {
		const actionView = document.getElementById('view');
		const actionSave = document.getElementById('save');

		let target = "_self";
		if (actionView && actionView.classList.contains('active'))
			target = document.getElementById("newWindowView").checked ? "WW_View" : "pg_editor_frame";
		else if (actionSave && actionSave.classList.contains('active'))
			target = document.getElementById("newWindowSave").checked ? "WW_View" : "pg_editor_frame";

		document.getElementById('editor').target = target;

		if (target == "pg_editor_frame") {
			busyIndicator = document.createElement('div');
			busyIndicator.classList.add('page-loading-busy-indicator');
			busyIndicator.innerHTML = '<div class="busy-text"><h2>Loading...</h2></div>' +
				'<div><i class="fas fa-circle-notch fa-spin fa-3x"></i></div>';
			document.body.appendChild(busyIndicator);
		}
	});
})();
