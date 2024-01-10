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

			if (export_select_target.selectedIndex === 0) export_elements.style.display = 'block';
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
			},
			{ once: true }
		);
		return false;
	};

	document.getElementById('user-list-form')?.addEventListener('submit', (e) => {
		const action = document.getElementById('current_action')?.value || '';
		if (action === 'filter') {
			const filter = document.getElementById('filter_select')?.selectedIndex || 0;
			const filter_text = document.getElementById('filter_text');
			if (filter === 2 && !is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
			} else if (filter === 3 && filter_text.value === '') {
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
		} else if (action === 'edit' || action === 'password') {
			if (!is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
			}
		} else if (action == 'export') {
			const export_filename = document.getElementById('export_filename');
			if (!is_user_selected()) {
				e.preventDefault();
				e.stopPropagation();
			} else if (
				document.getElementById('export_select_target')?.value === 'new' &&
				export_filename.value === ''
			) {
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('export_file_err_msg')?.classList.remove('d-none');
				export_filename.classList.add('is-invalid');
				export_filename.addEventListener(
					'change',
					() => {
						document.getElementById('export_filename')?.classList.remove('is-invalid');
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

	// Remove select error message when changing tabs.
	for (const tab of document.querySelectorAll('a[data-bs-toggle="tab"]')) {
		tab.addEventListener('shown.bs.tab', () => {
			document.getElementById('select_user_err_msg')?.classList.add('d-none');
		});
	}
})();
