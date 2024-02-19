(() => {
	// Action form validation.
	const is_achievement_selected = () => {
		for (const achievement of document.getElementsByName('selected_achievements')) {
			if (achievement.checked) return true;
		}
		document.getElementById('select_achievement_err_msg')?.classList.remove('d-none');
		document.getElementById('achievement-table')?.addEventListener(
			'change',
			() => {
				document.getElementById('select_achievement_err_msg')?.classList.add('d-none');
				for (const id of ['filter_select', 'edit_select', 'assign_select', 'export_select', 'score_select']) {
					document.getElementById(id)?.classList.remove('is-invalid');
				}
			},
			{ once: true }
		);
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
				filter_select?.classList.add('is-invalid');
				filter_select?.addEventListener(
					'change',
					() => {
						document.getElementById('select_achievement_err_msg').classList.add('d-none');
						document.getElementById('filter_select').classList.remove('is-invalid');
					},
					{ once: true }
				);
			} else if (filter === 'match_ids' && filter_text?.value === '') {
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('filter_text_err_msg')?.classList.remove('d-none');
				filter_select?.classList.add('is-invalid');
				filter_text?.classList.add('is-invalid');
				filter_text?.addEventListener(
					'change',
					() => {
						document.getElementById('filter_text_err_msg')?.classList.add('d-none');
						document.getElementById('filter_text')?.classList.remove('is-invalid');
						document.getElementById('filter_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
				filter_select?.addEventListener(
					'change',
					() => {
						document.getElementById('filter_text_err_msg')?.classList.add('d-none');
						document.getElementById('filter_text')?.classList.remove('is-invalid');
						document.getElementById('filter_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			} else if (filter === 'match_category' && filter_category?.value === '') {
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('filter_category_err_msg')?.classList.remove('d-none');
				filter_select?.classList.add('is-invalid');
				filter_category?.classList.add('is-invalid');
				filter_category?.addEventListener(
					'change',
					() => {
						document.getElementById('filter_category_err_msg')?.classList.add('d-none');
						document.getElementById('filter_category')?.classList.remove('is-invalid');
						document.getElementById('filter_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
				filter_select?.addEventListener(
					'change',
					() => {
						document.getElementById('filter_category_err_msg')?.classList.add('d-none');
						document.getElementById('filter_category')?.classList.remove('is-invalid');
						document.getElementById('filter_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			}
		} else if (action === 'edit') {
			const edit_select = document.getElementById('edit_select');
			if (edit_select.value === 'selected' && !is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
				edit_select.classList.add('is-invalid');
				edit_select.addEventListener(
					'change',
					() => {
						document.getElementById('select_achievement_err_msg')?.classList.add('d-none');
						document.getElementById('edit_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			}
		} else if (action === 'assign') {
			const assign_select = document.getElementById('assign_select');
			if (assign_select.value === 'selected' && !is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
				assign_select.classList.add('is-invalid');
				assign_select.addEventListener(
					'change',
					() => {
						document.getElementById('select_achievement_err_msg')?.classList.add('d-none');
						document.getElementById('assign_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			}
		} else if (action === 'import') {
			const import_file = document.getElementById('import_file_select');
			if (!import_file.value.endsWith('.axp')) {
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('import_file_err_msg')?.classList.remove('d-none');
				import_file.classList.add('is-invalid');
				import_file.addEventListener(
					'change',
					() => {
						document.getElementById('import_file_err_msg')?.classList.add('d-none');
						document.getElementById('import_file_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			}
		} else if (action === 'export') {
			const export_select = document.getElementById('export_select');
			if (export_select.value === 'selected' && !is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
				export_select.classList.add('is-invalid');
				export_select.addEventListener(
					'change',
					() => {
						document.getElementById('select_achievement_err_msg')?.classList.add('d-none');
						document.getElementById('export_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			}
		} else if (action === 'score') {
			const score_select = document.getElementById('score_select');
			if (export_select.value === 'selected' && !is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
				score_select.classList.add('is-invalid');
				score_select.addEventListener(
					'change',
					() => {
						document.getElementById('select_achievement_err_msg')?.classList.add('d-none');
						document.getElementById('score_select')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			}
		} else if (action === 'create') {
			const create_text = document.getElementById('create_text');
			if (create_text.value === '') {
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('create_file_err_msg')?.classList.remove('d-none');
				create_text.classList.add('is-invalid');
				create_text.addEventListener(
					'change',
					() => {
						document.getElementById('create_file_err_msg')?.classList.add('d-none');
						document.getElementById('create_text')?.classList.remove('is-invalid');
					},
					{ once: true }
				);
			} else if (document.getElementById('create_select')?.value == 'copy' && !is_achievement_selected()) {
				e.preventDefault();
				e.stopPropagation();
			}
		} else if (action === 'delete') {
			const delete_confirm = document.getElementById('delete_select');
			if (!is_achievement_selected()) {
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
			const actionForm = document.getElementById('achievement-list');
			for (const err_msg of actionForm.querySelectorAll('div[id$=_err_msg]')) {
				err_msg.classList.add('d-none');
			}
			for (const invalid of actionForm.querySelectorAll('.is-invalid')) {
				invalid.classList.remove('is-invalid');
			}
		});
	}

	// Toggle the display of the filter elements as the filter select changes.
	const filter_select = document.getElementById('filter_select');
	const filter_text_elements = document.getElementById('filter_text_elements');
	const filter_category_elements = document.getElementById('filter_category_elements');
	const filterElementToggle = () => {
		if (filter_select?.value === 'match_ids') filter_text_elements.style.display = 'flex';
		else filter_text_elements.style.display = 'none';
		if (filter_select?.value === 'match_category' ) filter_category_elements.style.display = 'flex';
		else filter_category_elements.style.display = 'none';
	};

	if (filter_select) filterElementToggle();
	filter_select?.addEventListener('change', filterElementToggle);
})();
