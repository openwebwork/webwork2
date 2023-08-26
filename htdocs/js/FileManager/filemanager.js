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

	// The bits for types from least to most significant digit are set in the directoryListing method of
	// lib/WeBWorK/ContentGenerator/Instructor/FileManager.pm to mean a file is a
	// link, directory, regular file, text file, or image file.
	const fileActionButtons = [
		{ id: 'View', types: 0b11010, multiple: 0 },
		{ id: 'Edit', types: 0b01000, multiple: 0 },
		{ id: 'Download', types: 0b100, multiple: 0 },
		{ id: 'Rename', types: 0b111, multiple: 0 },
		{ id: 'Copy', types: 0b100, multiple: 0 },
		{ id: 'Delete', types: 0b111, multiple: 1 },
		{ id: 'MakeArchive', types: 0b111, multiple: 1 }
	];
	fileActionButtons.map((button) => (button.elt = document.getElementById(button.id)));
	const archiveButton = document.getElementById('MakeArchive');

	const checkFiles = () => {
		const selectedFiles = files.selectedOptions;

		for (const button of fileActionButtons) {
			if (!button.elt) continue;
			if (selectedFiles.length) {
				if (selectedFiles.length == 1 && !button.multiple)
					button.elt.disabled = !(button.types & selectedFiles[0].dataset.type);
				else button.elt.disabled = !button.multiple;
			} else {
				button.elt.disabled = true;
			}
		}

		if (archiveButton && selectedFiles.length) {
			if (selectedFiles.length > 1 || !/\.(tar|tar\.gz|tgz|zip)$/.test(selectedFiles[0].value))
				archiveButton.value = archiveButton.dataset.archiveText;
			else archiveButton.value = archiveButton.dataset.unarchiveText;
		}
	};

	files?.addEventListener('change', checkFiles);
	if (files) checkFiles();

	const archiveFilenameInput = document.getElementById('archive-filename');
	const archiveTypeSelect = document.getElementById('archive-type');
	if (archiveFilenameInput && archiveTypeSelect) {
		archiveTypeSelect.addEventListener('change', () => {
			if (archiveTypeSelect.value) {
				archiveFilenameInput.value = archiveFilenameInput.value.replace(
					/\.(zip|tgz|tar.gz)$/,
					`.${archiveTypeSelect.value}`
				);
			}
		});
	}

	const file = document.getElementById('file');
	const uploadButton = document.getElementById('Upload');
	const checkFile = () => (uploadButton.disabled = file.value === '');
	if (uploadButton) file?.addEventListener('change', checkFile);
	if (file) checkFile();
})();
