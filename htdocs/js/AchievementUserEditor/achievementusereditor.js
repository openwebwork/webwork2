(() => {
	const allAssignedCheckboxes = document.querySelectorAll('input[type="checkbox"][name$=".achievement"]');
	const allEarnedCheckboxes = document.querySelectorAll('[name$=".earned"]');
	const allCounters = document.querySelectorAll('[name$=".counter"]');

	// Confirmation when an achievement is unassigned from users.
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

	const uncheckedCheckboxes = [];
	unassign_confirm_dialog?.addEventListener('hide.bs.modal', () => {
		if (unassign_confirmed) return;
		for (const checkbox of uncheckedCheckboxes) {
			checkbox.checked = true;
		}
		uncheckedCheckboxes.length = 0;
	});

	document.getElementById('user-achievement-form')?.addEventListener('submit', (e) => {
		const action = e.submitter?.name;
		if (action === 'assignToAll') {
			for (const checkbox of allAssignedCheckboxes) {
				checkbox.checked = true;
			}
			// Set to false to avoid unassigning users intentionally.
			const confirmInput = document.getElementsByName('allow_unassign')[0];
			if (confirmInput) confirmInput.value = 0;
		} else if (action === 'unassignFromAll' || action === 'assignToSelected') {
			if (action === 'unassignFromAll') {
				uncheckedCheckboxes.length = 0;
				// Uncheck all users.
				for (const checkbox of allAssignedCheckboxes) {
					if (checkbox.checked) uncheckedCheckboxes.push(checkbox);
					checkbox.checked = false;
				}
			}

			// Check if any sets have been unchecked.
			const uncheckedAchievements = [];
			for (const checkbox of allAssignedCheckboxes) {
				if (checkbox.checked === false && checkbox.dataset.isAssigned === '1')
					uncheckedAchievements.push(checkbox.dataset.username);
			}
			if (uncheckedAchievements.length > 0) {
				if (unassign_confirmed) {
					unassign_confirmed = false;
					return;
				}
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('unassign_confirm_user_list')?.replaceChildren(
					...uncheckedAchievements.map((userName) => {
						const item = document.createElement('li');
						item.textContent = userName;
						return item;
					})
				);
				unassign_confirm_modal?.show();
			}
		}
	});

	for (const button of document.getElementsByName('reset-button')) {
		button.addEventListener('click', () => {
			for (const checkbox of allAssignedCheckboxes) {
				checkbox.checked = checkbox.dataset.isAssigned === '1';
			}
			for (const checkbox of allEarnedCheckboxes) {
				checkbox.checked = checkbox.dataset.isEarned === '1';
			}
			for (const counter of allCounters) {
				counter.value = counter.dataset.initialCount;
			}
		});
	}
})();
