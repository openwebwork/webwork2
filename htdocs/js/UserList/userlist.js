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
	const is_user_selected = () => {
		for (const user of document.getElementsByName('selected_users')) {
			if (user.checked) return true;
		}
		document.getElementById('select_user_err_msg')?.classList.remove('d-none');
		document.getElementById('classlist-table')?.addEventListener(
			'change',
			() => {
				document.getElementById('select_user_err_msg')?.classList.add('d-none');
				for (const id of ['filter_select', 'edit_select', 'password_select', 'export_select_scope']) {
					document.getElementById(id)?.classList.remove('is-invalid');
				}
			},
			{ once: true }
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
				filter_select.classList.add('is-invalid');
				filter_select.addEventListener(
					'change',
					() => {
						document.getElementById('select_user_err_msg')?.classList.add('d-none');
						document.getElementById('filter_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			} else if (filter === 'match_regex' && filter_text.value === '') {
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('filter_err_msg')?.classList.remove('d-none');
				filter_text.classList.add('is-invalid');
				filter_text.addEventListener(
					'change',
					() => {
						document.getElementById('filter_text')?.classList.remove('is-invalid');
						document.getElementById('filter_err_msg')?.classList.add('d-none');
					},
					{ once: true }
				);
			}
		} else if (action === 'edit') {
			const edit_select = document.getElementById('edit_select');
			if (edit_select.value === 'selected' && !is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
				edit_select.classList.add('is-invalid');
				edit_select.addEventListener(
					'change',
					() => {
						document.getElementById('select_user_err_msg')?.classList.add('d-none');
						document.getElementById('edit_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			}
		} else if (action === 'password') {
			const password_select = document.getElementById('password_select');
			if (password_select.value === 'selected' && !is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
				password_select.classList.add('is-invalid');
				password_select.addEventListener(
					'change',
					() => {
						document.getElementById('select_user_err_msg')?.classList.add('d-none');
						document.getElementById('password_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			}
		} else if (action == 'export') {
			const export_filename = document.getElementById('export_filename');
			const export_select = document.getElementById('export_select_scope');
			if (export_select.value === 'selected' && !is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
				export_select.classList.add('is-invalid');
				export_select.addEventListener(
					'change',
					() => {
						document.getElementById('select_user_err_msg')?.classList.add('d-none');
						document.getElementById('export_select_scope')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			} else if (
				document.getElementById('export_select_target')?.value === 'new' &&
				export_filename.value === ''
			) {
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('export_file_err_msg')?.classList.remove('d-none');
				document.getElementById('export_select_target')?.classList.add('is-invalid');
				export_filename.classList.add('is-invalid');
				export_filename.addEventListener(
					'change',
					() => {
						document.getElementById('export_filename')?.classList.remove('is-invalid');
						document.getElementById('export_select_target')?.classList.remove('is-invalid');
						document.getElementById('export_file_err_msg')?.classList.add('d-none');
					},
					{ once: true }
				);
				document.getElementById('export_select_target')?.addEventListener(
					'change',
					() => {
						document.getElementById('export_filename')?.classList.remove('is-invalid');
						document.getElementById('export_select_target')?.classList.remove('is-invalid');
						document.getElementById('export_file_err_msg')?.classList.add('d-none');
					},
					{ once: true }
				);
			}
		} else if (action === 'delete') {
			const delete_confirm = document.getElementById('delete_select');
			if (!is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
			} else if (delete_confirm.value != 'yes') {
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('delete_confirm_err_msg')?.classList.remove('d-none');
				delete_confirm.classList.add('is-invalid');
				delete_confirm.addEventListener(
					'change',
					() => {
						document.getElementById('delete_select')?.classList.remove('is-invalid');
						document.getElementById('delete_confirm_err_msg')?.classList.add('d-none');
					},
					{ once: true }
				);
			}
		}
	});

	// Remove all error messages when changing tabs.
	for (const tab of document.querySelectorAll('a[data-bs-toggle="tab"]')) {
		tab.addEventListener('shown.bs.tab', () => {
			const actionForm = document.getElementById('user-list-form');
			for (const err_msg of actionForm.querySelectorAll('div[id$=_err_msg]')) {
				err_msg.classList.add('d-none');
			}
			for (const invalid of actionForm.querySelectorAll('.is-invalid')) {
				invalid.classList.remove('is-invalid');
			}
		});
	}
})();
