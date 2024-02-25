(() => {
	// Action form validation.
	// Store event listeners so they can be removed.
	const event_listeners = {};

	const show_errors = (ids, elements) => {
		for (const id of ids) elements.push(document.getElementById(id));
		for (const element of elements) {
			if (element?.id.endsWith('_err_msg')) {
				element?.classList.remove('d-none');
			} else {
				element?.classList.add('is-invalid');
				if (!(element.id in event_listeners)) {
					event_listeners[element.id] = hide_errors([], elements);
					element?.addEventListener('change', event_listeners[element.id]);
				}
			}
		}
	};

	const hide_errors = (ids, elements) => {
		return () => {
			for (const id of ids) elements.push(document.getElementById(id));
			for (const element of elements) {
				if (element?.id.endsWith('_err_msg')) {
					element?.classList.add('d-none');
					if (element.id === 'select_achievement_err_msg' && 'achievement_table' in event_listeners) {
						document
							.getElementById('achievement-table')
							?.removeEventListener('change', event_listeners.achievement_table);
						delete event_listeners.achievement_table;
					}
				} else {
					element?.classList.remove('is-invalid');
					if (element.id in event_listeners) {
						element?.removeEventListener('change', event_listeners[element.id]);
						delete event_listeners[element.id];
					}
				}
			}
		};
	};

	const is_achievement_selected = () => {
		for (const achievement of document.getElementsByName('selected_achievements')) {
			if (achievement.checked) return true;
		}
		const err_msg = document.getElementById('select_achievement_err_msg');
		err_msg?.classList.remove('d-none');
		if (!('achievement_table' in event_listeners)) {
			event_listeners.achievement_table = hide_errors(
				['filter_select', 'edit_select', 'assign_select', 'export_select', 'score_select'],
				[err_msg]
			);
			document.getElementById('achievement-table')?.addEventListener('change', event_listeners.achievement_table);
		}
		return false;
	};

	document.getElementById('achievement-list')?.addEventListener('submit', (e) => {
		const action = document.getElementById('current_action')?.value || '';
		if (action === 'filter') {
			const filter_select = document.getElementById('filter_select');
			const filter = filter_select?.value || '';
			const filter_text = document.getElementById('filter_text');
			const filter_category = document.getElementById('filter_category');
			if (filter === 'selected' && !is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_achievement_err_msg'], [filter_select]);
			} else if (filter === 'match_ids' && filter_text?.value === '') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['filter_text_err_msg'], [filter_select, filter_text]);
			} else if (filter === 'match_category' && filter_category?.value === '') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['filter_category_err_msg'], [filter_select, filter_category]);
			}
		} else if (['edit', 'assign', 'export', 'score'].includes(action)) {
			const action_select = document.getElementById(`${action}_select`);
			if (action_select.value === 'selected' && !is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_achievement_err_msg'], [action_select]);
			}
		} else if (action === 'import') {
			const import_file = document.getElementById('import_file_select');
			if (!import_file.value.endsWith('.axp')) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['import_file_err_msg'], [import_file]);
			}
		} else if (action === 'create') {
			const create_text = document.getElementById('create_text');
			const create_select = document.getElementById('create_select');
			if (create_text.value === '') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['create_file_err_msg'], [create_text]);
			} else if (create_select?.value == 'copy' && !is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_achievement_err_msg'], [create_select]);
			}
		} else if (action === 'delete') {
			const delete_confirm = document.getElementById('delete_select');
			if (!is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
			} else if (delete_confirm.value != 'yes') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['delete_confirm_err_msg'], [delete_confirm]);
			}
		}
	});

	// Remove all error messages when changing tabs.
	for (const tab of document.querySelectorAll('a[data-bs-toggle="tab"]')) {
		tab.addEventListener('shown.bs.tab', () => {
			if (Object.keys(event_listeners).length != 0)
				hide_errors(
					[],
					document.getElementById('achievement-list')?.querySelectorAll('div[id$=_err_msg], .is-invalid')
				)();
		});
	}

	// Toggle the display of the filter elements as the filter select changes.
	const filter_select = document.getElementById('filter_select');
	const filter_text_elements = document.getElementById('filter_text_elements');
	const filter_category_elements = document.getElementById('filter_category_elements');
	const filterElementToggle = () => {
		if (filter_select?.value === 'match_ids') filter_text_elements.style.display = 'flex';
		else filter_text_elements.style.display = 'none';
		if (filter_select?.value === 'match_category') filter_category_elements.style.display = 'flex';
		else filter_category_elements.style.display = 'none';
	};

	if (filter_select) filterElementToggle();
	filter_select?.addEventListener('change', filterElementToggle);
})();
