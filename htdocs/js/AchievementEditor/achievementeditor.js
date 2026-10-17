(() => {
	// Action form validation.
	// Store event listeners so they can be removed.
	const event_listeners = {};

	const show_errors = (ids, elements) => {
		for (const id of ids) elements.push(document.getElementById(id));
		for (const element of elements) {
			if (element?.id.endsWith('_err_msg')) {
				element.classList.remove('d-none');
			} else if (element) {
				element.classList.add('is-invalid');
				if (!(element.id in event_listeners)) {
					event_listeners[element.id] = hide_errors([], elements);
					element.addEventListener('change', event_listeners[element.id]);
				}
			}
		}
	};

	const hide_errors = (ids, elements) => {
		return () => {
			for (const id of ids) elements.push(document.getElementById(id));
			for (const element of elements) {
				if (element?.id.endsWith('_err_msg')) {
					element.classList.add('d-none');
				} else if (element) {
					element.classList.remove('is-invalid');
					if (element.id in event_listeners) {
						element.removeEventListener('change', event_listeners[element.id]);
						delete event_listeners[element.id];
					}
				}
			}
		};
	};

	// Confirmation before deleting a course override.
	let revert_confirmed = false;
	const revert_confirm_dialog = document.getElementById('revert_confirm_dialog');
	const revert_confirm_modal = revert_confirm_dialog ? new bootstrap.Modal(revert_confirm_dialog) : null;
	document.getElementById('revert_confirm_proceed')?.addEventListener('click', () => {
		revert_confirmed = true;
		revert_confirm_modal?.hide();
		const confirmInput = document.getElementsByName('action.revert.confirm')[0];
		if (confirmInput) confirmInput.value = 1;
		document.getElementById('take_action')?.click();
	});

	document.getElementById('editor')?.addEventListener('submit', (e) => {
		const action = document.getElementById('current_action')?.value || '';
		if (action === 'save_as') {
			const target_file_input = document.getElementById('action.save_as.target_file_id');
			const value = target_file_input?.value.trim() || '';
			const filename = value.endsWith('.at') ? value : `${value}.at`;
			if (filename === '.at') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['blank_filename_err_msg'], [target_file_input]);
			} else if (filename == target_file_input.dataset.originalName) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['change_filename_err_msg'], [target_file_input]);
			} else if (
				filename.startsWith('/') ||
				filename.startsWith('..') ||
				filename.includes('/..') ||
				filename.includes('../') ||
				filename.endsWith('/.at')
			) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['invalid_filename_err_msg'], [target_file_input]);
			} else {
				const selectedOption =
					document.querySelector('input[name="action.save_as.saveMode"]:checked')?.value || '';
				if (selectedOption === 'use_in_new') {
					const newFilename = document.getElementById('action.save_as.new_id');
					if (newFilename?.value.trim() === '') {
						e.preventDefault();
						e.stopPropagation();
						show_errors(['blank_id_err_msg'], [newFilename]);
					}
				}
			}
		} else if (action === 'revert' && revert_confirm_modal) {
			if (revert_confirmed) {
				revert_confirmed = false;
				return;
			}
			e.preventDefault();
			e.stopPropagation();
			revert_confirm_modal.show();
		}
	});

	// Remove all error messages when changing tabs.
	for (const tab of document.querySelectorAll('a[data-bs-toggle="tab"]')) {
		tab.addEventListener('shown.bs.tab', () => {
			if (Object.keys(event_listeners) != 0)
				hide_errors(
					[],
					document.getElementById('editor')?.querySelectorAll('div[id$=_err_msg], .is-invalid')
				)();
		});
	}
})();
