(() => {
	const allCheckboxes = document.querySelectorAll('input[type="checkbox"][name^="set."][name$=".assignment"]');

	// Check or uncheck assignment checkboxes for versioned sets and their template to make it clear to the user what
	// the backend will do with their selections.
	allCheckboxes.forEach((checkbox) => {
		const setID = checkbox.dataset.setId;
		if (checkbox.dataset.versioned !== undefined) {
			// This is a versioned set.  If this is checked, make sure that the template set is also checked.
			checkbox.addEventListener('change', () => {
				if (checkbox.checked)
					document.querySelector(
						`input[type="checkbox"][data-set-id="${setID}"]:not([data-versioned])`
					).checked = true;
			});
		} else {
			// This is a global set that may be versioned.
			// So if it is unchecked, also uncheck any versions that may exist.
			checkbox.addEventListener('change', () => {
				if (!checkbox.checked) {
					document
						.querySelectorAll(`input[type="checkbox"][data-set-id="${setID}"][data-versioned]`)
						.forEach((versionCheckbox) => (versionCheckbox.checked = false));
				}
			});
		}
	});

	// Confirmation when a set is unassigned.
	let unassign_confirmed = false;
	const unassign_confirm_dialog = document.getElementById('unassign_confirm_dialog');
	const unassign_confirm_modal = unassign_confirm_dialog ? new bootstrap.Modal(unassign_confirm_dialog) : null;
	document.getElementById('unassign_confirm_proceed')?.addEventListener('click', () => {
		unassign_confirmed = true;
		unassign_confirm_modal?.hide();
		const confirmInput = document.getElementsByName('allow_unassign')[0];
		if (confirmInput) confirmInput.value = 1;
		document.getElementsByName('save_button')[0]?.click();
	});

	document.getElementById('UserDetail')?.addEventListener('submit', (e) => {
		const action = e.submitter?.name;
		if (action === 'assignAll') {
			// If the "Assign All Sets to Current User" button is clicked, then check all assignments.
			allCheckboxes.forEach((checkbox) => {
				checkbox.checked = true;
			});
		} else if (action === 'save_button') {
			// Check if any sets have been unchecked.
			const uncheckedSets = [];
			allCheckboxes.forEach((checkbox) => {
				if (checkbox.checked === false && checkbox.dataset.isAssigned === '1')
					uncheckedSets.push(checkbox.dataset.formattedSetName);
			});
			if (uncheckedSets.length > 0) {
				if (unassign_confirmed) {
					unassign_confirmed = false;
					return;
				}
				e.preventDefault();
				e.stopPropagation();
				document.getElementById('unassign_confirm_set_list')?.replaceChildren(
					...uncheckedSets.map((setId) => {
						const item = document.createElement('li');
						item.textContent = setId;
						return item;
					})
				);
				unassign_confirm_modal?.show();
			}
		}
	});
})();
