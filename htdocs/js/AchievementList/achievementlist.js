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
				for (const id of ['edit_select', 'assign_select', 'export_select', 'score_select']) {
					document.getElementById(id)?.classList.remove('is-invalid');
				}
			},
			{ once: true }
		);
		return false;
	};

	document.getElementById('achievement-list')?.addEventListener('submit', (e) => {
		const action = document.getElementById('current_action')?.value || '';
		if (action === 'edit') {
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
			} else if (document.getElementById('create_select')?.selectedIndex == 1 && !is_achievement_selected()) {
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
})();
