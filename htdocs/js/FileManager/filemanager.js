'use strict';
(() => {
	const form = window.document.getElementById('FileManager');

	const files = document.getElementById('files');

	if (form) {
		const doAction = (action) => {
			form.formAction.value = action;
			form.submit();
		};

		document.getElementsByName('directory')[0]?.addEventListener('change', () => doAction('Go'));
		document.getElementsByName('dates')[0]?.addEventListener('click', () => doAction('Refresh'));
		files?.addEventListener('dblclick', () => doAction('View'));

		// If on the confirmation page, then focus the "name" input.
		form.querySelector('input[name="name"]')?.focus();
	}

	const fileActionButtons = ['View', 'Edit', 'Download', 'Rename', 'Copy', 'Delete', 'MakeArchive'].map((buttonId) =>
		document.getElementById(buttonId)
	);
	const archiveButton = document.getElementById('MakeArchive');

	const checkFiles = () => {
		const state = files.selectedIndex < 0;

		for (const button of fileActionButtons) {
			if (button) button.disabled = state;
		}

		if (archiveButton && !state) {
			const numSelected = files.querySelectorAll('option:checked').length;
			if (
				numSelected === 0 ||
				numSelected > 1 ||
				!/\.(tar|tar\.gz|tgz)$/.test(files.children[files.selectedIndex].value)
			)
				archiveButton.value = archiveButton.dataset.archiveText;
			else archiveButton.value = archiveButton.dataset.unarchiveText;
		}
	};

	files?.addEventListener('change', checkFiles);
	if (files) checkFiles();

	const file = document.getElementById('file');
	const uploadButton = document.getElementById('Upload');
	const checkFile = () => (uploadButton.disabled = file.value === '');
	if (uploadButton) file?.addEventListener('change', checkFile);
	if (file) checkFile();
})();
