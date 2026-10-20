(() => {
	const allCheckboxes = document.getElementsByName('selected');

	// Confirmation when a set is unassigned.
	let unassign_confirmed = false;
	const unassign_confirm_dialog = document.getElementById('unassign_confirm_dialog');
	const unassign_confirm_modal = unassign_confirm_dialog ? new bootstrap.Modal(unassign_confirm_dialog) : null;
	document.getElementById('unassign_confirm_proceed')?.addEventListener('click', () => {
		unassign_confirmed = true;
		unassign_confirm_modal?.hide();
		const confirmInput = document.getElementsByName('allow_unassign')[0];
		if (confirmInput) confirmInput.value = 1;
		document.getElementsByName('assignToSelected')[0]?.click();
	});

	document.getElementById('assignForm')?.addEventListener('submit', (e) => {
		const action = e.submitter?.name;
		if (action === 'assignToAll') {
			// Check all current users.
			allCheckboxes.forEach((checkbox) => {
				if (checkbox.dataset.isCurrent === '1') checkbox.checked = true;
			});
			// Set to false to avoid unassigning users intentionally.
			const confirmInput = document.getElementsByName('allow_unassign')[0];
			if (confirmInput) confirmInput.value = 0;
		} else if (action === 'unassignFromAll' || action === 'assignToSelected') {
			if (action === 'unassignFromAll') {
				// Uncheck all users.
				allCheckboxes.forEach((checkbox) => {
					checkbox.checked = false;
				});
			}

			// Check if any sets have been unchecked.
			const uncheckedSets = [];
			allCheckboxes.forEach((checkbox) => {
				if (checkbox.checked === false && checkbox.dataset.isAssigned === '1')
					uncheckedSets.push(checkbox.dataset.username);
			});
			if (uncheckedSets.length > 0) {
				if (unassign_confirmed) {
					unassign_confirmed = false;
					return;
				}
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('unassign_confirm_user_list')?.replaceChildren(
					...uncheckedSets.map((userName) => {
						const item = document.createElement('li');
						item.textContent = userName;
						return item;
					})
				);
				unassign_confirm_modal?.show();
			}
		}
	});
})();
