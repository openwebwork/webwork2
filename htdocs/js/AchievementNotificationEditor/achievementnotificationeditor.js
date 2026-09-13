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

	document.getElementById('editor')?.addEventListener('submit', (e) => {
		const action = document.getElementById('current_action')?.value || '';
		if (action === 'save_as') {
			const target_file_input = document.getElementById('action.save_as.target_file_id');
			const filename = target_file_input?.value || '';
			if (filename.trim() === '') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['blank_filename_err_msg'], [target_file_input]);
			} else if (filename == target_file_input.dataset.originalName) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['change_filename_err_msg'], [target_file_input]);
			} else if (filename.includes('/')) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['invalid_filename_err_msg'], [target_file_input]);
			}
		}
	});

	// Remove all error messages when changing tabs.
	for (const tab of document.querySelectorAll('a[data-bs-toggle="tab"]')) {
		tab.addEventListener('shown.bs.tab', () => {
			if (Object.keys(event_listeners).length)
				hide_errors(
					[],
					document.getElementById('editor')?.querySelectorAll('div[id$=_err_msg], .is-invalid')
				)();
		});
	}
})();
