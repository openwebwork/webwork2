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
		files?.addEventListener('dblclick', () => {
			if (files.selectedOptions[0].dataset.type & 0b11010) doAction('View');
			else {
				const container = document.createElement('div');
				container.classList.add('toast-container', 'top-50', 'start-50', 'translate-middle');

				const toast = document.createElement('div');
				toast.classList.add('toast');
				toast.setAttribute('role', 'alert');
				toast.setAttribute('aria-live', 'assertive');
				toast.setAttribute('aria-atomit', 'true');
				const toastContent = document.createElement('div');
				toastContent.classList.add('d-flex', 'alert', 'alert-danger', 'mb-0', 'p-0');

				const toastBody = document.createElement('div');
				toastBody.classList.add('toast-body');
				toastBody.textContent =
					files.selectedOptions[0].dataset.type & 0b1
						? files.dataset.linkMessage || 'Symbolic links can not be followed.'
						: files.dataset.nonViewableMessage || 'This is not a viewable file type.';

				const closeButton = document.createElement('button');
				closeButton.type = 'button';
				closeButton.classList.add('btn-close', 'me-2', 'm-auto');
				closeButton.dataset.bsDismiss = 'toast';
				closeButton.setAttribute('aria-label', files.dataset.closeTitle || 'Close');

				toastContent.append(toastBody, closeButton);

				toast.append(toastContent);
				container.append(toast);
				document.body.append(container);

				const bsToast = new bootstrap.Toast(toast);
				bsToast.show();
				toast.addEventListener('hidden.bs.toast', () => {
					bsToast.dispose();
					container.remove();
				});
			}
		});

		// If on the confirmation page, then focus the "name" input.
		form.querySelector('input[name="name"]')?.focus();
	}

	// The bits for types from least to most significant digit are set in the directoryListing method of
	// lib/WeBWorK/ContentGenerator/Instructor/FileManager.pm to mean a file is a
	// link, directory, regular file, text file, or image file.
	const fileActions = [
		{ id: 'View', types: 0b11010, multiple: 0 },
		{ id: 'Edit', types: 0b01000, multiple: 0 },
		{ id: 'Download', types: 0b100, multiple: 0 },
		{ id: 'Rename', types: 0b111, multiple: 0 },
		{ id: 'Copy', types: 0b100, multiple: 0 },
		{ id: 'Delete', types: 0b111, multiple: 1 },
		{ id: 'MakeArchive', types: 0b111, multiple: 1 }
	];
	fileActions.map((button) => (button.elt = document.getElementById(button.id)));
	const archiveButton = document.getElementById('MakeArchive');

	const checkFiles = () => {
		const selectedFiles = files.selectedOptions;

		for (const button of fileActions) {
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
