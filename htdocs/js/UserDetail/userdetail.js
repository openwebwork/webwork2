(() => {
	// Check or uncheck assignment checkboxes for versioned sets and their template to make it clear to the user what
	// the backend will do with their selections.
	document.querySelectorAll('input[type="checkbox"][name^="set."][name$=".assignment"]').forEach((checkbox) => {
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

	// If the "Assign All Sets to Current User" button is clicked, then check all assignments.
	document.getElementsByName('assignAll').forEach((button) => {
		button.addEventListener('click', () => {
			document
				.querySelectorAll('input[name^="set."][name$=".assignment"]')
				.forEach((check) => (check.checked = true));
		});
	});
})();
