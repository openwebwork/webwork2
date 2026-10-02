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
					if (element.id === 'select_user_err_msg' && 'classlist_table' in event_listeners) {
						document
							.getElementById('classlist-table')
							?.removeEventListener('change', event_listeners.classlist_table);
						delete event_listeners.classlist_table;
					}
				} else {
					element?.classList.remove('is-invalid');
					if (element && element.id in event_listeners) {
						element?.removeEventListener('change', event_listeners[element.id]);
						delete event_listeners[element.id];
					}
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
		if (!('classlist_table' in event_listeners)) {
			event_listeners.classlist_table = hide_errors(
				['filter_select', 'edit_select', 'password_select', 'export_select_scope'],
				[err_msg]
			);
			document.getElementById('classlist-table')?.addEventListener('change', event_listeners.classlist_table);
		}
		return false;
	};

	// Actions that require confirmation via a dialog listing the selected users that will be affected.
	const confirm_dialogs = {};
	for (const action of ['delete', 'reset_2fa']) {
		const dialog = document.getElementById(`${action}_confirm_dialog`);
		if (!dialog) continue;
		confirm_dialogs[action] = { dialog, modal: new bootstrap.Modal(dialog), confirmed: false };
		document.getElementById(`${action}_confirm_proceed`)?.addEventListener('click', () => {
			confirm_dialogs[action].confirmed = true;
			confirm_dialogs[action].modal.hide();
			const confirmInput = document.getElementsByName(`action.${action}.confirm`)[0];
			if (confirmInput) confirmInput.value = 1;
			document.getElementById('take_action')?.click();
		});
	}

	const show_confirm_dialog = (action) => {
		const { dialog, modal } = confirm_dialogs[action];
		const current_user = dialog.dataset.currentUser;
		const current_user_checkbox = document.getElementById(`${current_user}_checkbox`);
		const affected_users = Array.from(document.querySelectorAll('input[name="selected_users"]:checked')).filter(
			(user) => user.value !== current_user
		);
		if (!affected_users.length) {
			show_errors([`${action}_self_err_msg`], [current_user_checkbox]);
			return;
		}
		hide_errors([`${action}_self_err_msg`], [current_user_checkbox])();
		document.getElementById(`${action}_confirm_user_list`)?.replaceChildren(
			...affected_users.map((user) => {
				const item = document.createElement('li');
				item.textContent = user.dataset.fullName ? `${user.value} (${user.dataset.fullName})` : user.value;
				return item;
			})
		);
		modal.show();
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
			} else if (
				export_select_target?.value === 'new' &&
				(export_filename.value === '' || /\//.test(export_filename.value))
			) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['export_file_err_msg'], [export_filename, export_select_target]);
			}
		} else if (action in confirm_dialogs) {
			if (confirm_dialogs[action].confirmed) {
				confirm_dialogs[action].confirmed = false;
				return;
			}
			e.preventDefault();
			e.stopPropagation();
			if (is_user_selected()) show_confirm_dialog(action);
		}
	});

	// Remove all error messages when changing tabs.
	for (const tab of document.querySelectorAll('a[data-bs-toggle="tab"]')) {
		tab.addEventListener('shown.bs.tab', () => {
			if (Object.keys(event_listeners) != 0)
				hide_errors(
					[],
					document.getElementById('user-list-form')?.querySelectorAll('div[id$=_err_msg], .is-invalid')
				)();
		});
	}

	for (const tooltipCheck of document.querySelectorAll(
		'input[name$="password_delete"]:not([disabled]), input[name$="password_must_reset"]'
	)) {
		new bootstrap.Tooltip(tooltipCheck, { placement: 'top', fallbackPlacements: [] });
	}

	// For a user with no password, the "force password reset" checkbox starts out unchecked (there is nothing to
	// reset yet). Automatically check it once a new password is actually typed into the corresponding password
	// field, and uncheck it again if that field is cleared back out. If the instructor manually toggles the
	// checkbox themselves, stop overriding their choice for the rest of the page's lifetime.
	for (const autoCheckbox of document.querySelectorAll('input[data-auto-check="password"]')) {
		const passwordField = autoCheckbox.closest('.row')?.querySelector('input[name$=".password"]');
		if (!passwordField) continue;

		let manuallySet = false;
		autoCheckbox.addEventListener('change', () => {
			manuallySet = true;
		});
		passwordField.addEventListener('input', () => {
			if (!manuallySet) autoCheckbox.checked = passwordField.value !== '';
		});
	}
})();
