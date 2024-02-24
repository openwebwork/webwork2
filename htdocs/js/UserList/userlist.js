(() => {
	// Show/hide the filter elements depending on if the field matching option is selected.
	const filter_select = document.getElementById('filter_select');
	const filter_elements = document.getElementById('filter_elements');
	if (filter_select && filter_elements) {
		const toggle_filter_elements = () => {
			if (filter_select.value === 'match_regex') filter_elements.style.display = 'block';
			else filter_elements.style.display = 'none';
		};
		filter_select.addEventListener('change', toggle_filter_elements);
		toggle_filter_elements();
	}

	const export_select_target = document.getElementById('export_select_target');
	if (export_select_target) {
		const classlist_add_export_elements = () => {
			const export_elements = document.getElementById('export_elements');
			if (!export_elements) return;

			if (export_select_target.value === 'new') export_elements.style.display = 'block';
			else export_elements.style.display = 'none';
		};

		export_select_target.addEventListener('change', classlist_add_export_elements);
		classlist_add_export_elements();
	}

	// Action form validation.
	const show_errors = (ids, elements) => {
		for (const id of ids) elements.push(document.getElementById(id));
		for (const element of elements) {
			if (element?.id.endsWith('_err_msg')) {
				element?.classList.remove('d-none');
			} else {
				element?.classList.add('is-invalid');
				element?.addEventListener('change', hide_errors([], elements));
			}
		}
	};

	const hide_errors = (ids, elements) => {
		return () => {
			for (const id of ids) elements.push(document.getElementById(id));
			for (const element of elements) {
				if (element?.id.endsWith('_err_msg')) {
					element?.classList.add('d-none');
					if (element.id === 'select_user_err_msg')
						document.getElementById('classlist-table')?.removeEventListener('change', hide_errors);
				} else {
					element?.classList.remove('is-invalid');
					element?.removeEventListener('change', hide_errors);
				}
			}
		};
	};

	const is_user_selected = () => {
		for (const user of document.getElementsByName('selected_users')) {
			if (user.checked) return true;
		}
		const err_msg = document.getElementById('select_user_err_msg');
		err_msg?.classList.remove('d-none');
		document
			.getElementById('classlist-table')
			?.addEventListener(
				'change',
				hide_errors(['filter_select', 'edit_select', 'password_select', 'export_select_scope'], [err_msg])
			);
		return false;
	};

	document.getElementById('user-list-form')?.addEventListener('submit', (e) => {
		const action = document.getElementById('current_action')?.value || '';
		if (action === 'filter') {
			const filter_select = document.getElementById('filter_select');
			const filter = filter_select?.value || '';
			const filter_text = document.getElementById('filter_text');
			if (filter === 'selected' && !is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_user_err_msg'], [filter_select]);
			} else if (filter === 'match_regex' && filter_text.value === '') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['filter_err_msg'], [filter_select, filter_text]);
			}
		} else if (['edit', 'password'].includes(action)) {
			const action_select = document.getElementById(`${action}_select`);
			if (action_select.value === 'selected' && !is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_user_err_msg'], [action_select]);
			}
		} else if (action == 'export') {
			const export_filename = document.getElementById('export_filename');
			const export_select = document.getElementById('export_select_scope');
			const export_select_target = document.getElementById('export_select_target');
			if (export_select.value === 'selected' && !is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_user_err_msg'], [export_select]);
			} else if (export_select_target?.value === 'new' && export_filename.value === '') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['export_file_err_msg'], [export_filename, export_select_target]);
			}
		} else if (action === 'delete') {
			const delete_confirm = document.getElementById('delete_select');
			if (!is_user_selected()) {
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
			hide_errors(
				[],
				document.getElementById('user-list-form')?.querySelectorAll('div[id$=_err_msg], .is-invalid')
			)();
		});
	}
})();
