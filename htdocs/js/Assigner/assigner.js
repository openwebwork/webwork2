(() => {
	// Store event listeners so they can be removed.
	const event_listeners = {};

	let unassign_confirmed = false;
	const unassign_confirm_dialog = document.getElementById('unassign_confirm_dialog');
	const unassign_confirm_modal = unassign_confirm_dialog ? new bootstrap.Modal(unassign_confirm_dialog) : null;
	document.getElementById('unassign_confirm_proceed')?.addEventListener('click', () => {
		unassign_confirmed = true;
		unassign_confirm_modal?.hide();
		const confirmInput = document.getElementsByName('confirm_unassign')[0];
		if (confirmInput) confirmInput.value = 1;
		document.getElementById('unassign_button')?.click();
	});

	const selectSets = document.getElementById('selected_sets');
	const selectUsers = document.getElementById('selected_users');

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

	document.getElementById('assign_form')?.addEventListener('submit', (e) => {
		if (e.submitter) {
			const action = e.submitter.name;
			if (action != 'assign' && action != 'unassign') {
				return;
			}

			const selectedSets = selectSets?.selectedOptions;
			const selectedUsers = selectUsers?.selectedOptions;
			if (selectedUsers && selectedUsers.length > 0 && selectedSets && selectedSets.length > 0) {
				if (action === 'unassign') {
					if (unassign_confirmed) {
						unassign_confirmed = false;
						return;
					}
					e.preventDefault();
					e.stopPropagation();
					document.getElementById('unassign_confirm_set_list')?.replaceChildren(
						...Array.from(selectedSets).map((set) => {
							const item = document.createElement('li');
							item.textContent = set.textContent;
							return item;
						})
					);
					document.getElementById('unassign_confirm_user_list')?.replaceChildren(
						...Array.from(selectedUsers).map((user) => {
							const item = document.createElement('li');
							item.textContent = user.textContent;
							return item;
						})
					);
					unassign_confirm_modal?.show();
				}
			} else {
				e.preventDefault();
				e.stopPropagation();
				if (selectedSets?.length === 0) {
					show_errors(['select_sets_err_msg'], [selectSets]);
				}
				if (selectedUsers?.length === 0) {
					show_errors(['select_users_err_msg'], [selectUsers]);
				}
			}
		} else {
			// Silently ignore submits that aren't a button push.
			e.preventDefault();
			e.stopPropagation();
		}
	});
})();
