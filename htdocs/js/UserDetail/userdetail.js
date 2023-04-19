(() => {
	// Check or uncheck assignment checkboxes for versioned sets and their template to make it clear to the user what
	// the backend will do with their selections.
	document.querySelectorAll('input[type="checkbox"][name^="set."][name$=".assignment"]').forEach((checkbox) => {
		const setID = checkbox.name.replace(/^set\.(.*).assignment$/, '$1');
		if (/,v\d*$/.test(setID)) {
			// This is a versioned set.  If this is checked, make sure that the template set is also checked.
			checkbox.addEventListener('change', () => {
				if (checkbox.checked)
					document.querySelector(`input[type="checkbox"][name="set.${
						setID.replace(/,v\d*$/, '')}.assignment"]`).checked = true;
			});
		} else {
			// This is a global set that may be versioned.
			// So if it is unchecked, also uncheck any versions that may exist.
			checkbox.addEventListener('change', () => {
				if (!checkbox.checked) {
					document.querySelectorAll(`input[type="checkbox"][name^="set.${setID},v"][name$=".assignment"]`)
						.forEach((versionCheckbox) => versionCheckbox.checked = false);
				}
			});
		}
	});

	// Make the date override checkboxes checked or unchecked appropriately
	// as determined by the value of the date input when that value changes.
	document.querySelectorAll('input[type="text"][data-override],input[type="hidden"][data-override]')
		.forEach((input) =>
	{
		const overrideCheck = document.getElementById(input.dataset.override);
		if (!overrideCheck) return;
		const changeHandler = () => overrideCheck.checked = input.value != '';
		input.addEventListener('change', changeHandler);
		// Attach the keyup and blur handlers to the flatpickr alternate input.
		input.previousElementSibling?.addEventListener('keyup', changeHandler);
		input.previousElementSibling?.addEventListener('blur',
			() => { if (input.previousElementSibling.value == '') overrideCheck.checked = false; });
	});

	// If the "Assign All Sets to Current User" button is clicked, then check all assignments.
	document.getElementsByName('assignAll').forEach((button) => {
		button.addEventListener('click', () => {
			document.querySelectorAll('input[name^="set."][name$=".assignment"]')
				.forEach((check) => check.checked = true);
		});
	});
})();
