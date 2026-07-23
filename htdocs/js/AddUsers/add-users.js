(() => {
	const passwordSelect = document.getElementById('fallback_password_source');

	const setPlaceholders = () => {
		for (const input of document.querySelectorAll('.new_password')) {
			let placeholder = 'placeholder';
			for (const part of passwordSelect.value.split('_')) {
				placeholder += part.charAt(0).toUpperCase() + part.slice(1);
			}
			input.setAttribute('placeholder', passwordSelect.dataset[placeholder]);
		}
	};

	passwordSelect.addEventListener('change', setPlaceholders);
	setPlaceholders();

	// Each "force password reset" checkbox starts out unchecked. Automatically check it once a password is typed
	// into that row's password field, or once a fallback password source other than "None" is selected (since that
	// fallback value will be used as the password for any row left blank). If the instructor manually toggles a
	// checkbox, stop overriding that row's checkbox for the rest of the page's lifetime.
	const manuallySet = new Set();
	for (const autoCheckbox of document.querySelectorAll('input[data-auto-check="password"]')) {
		const passwordField = autoCheckbox.closest('tr')?.querySelector('.new_password');
		if (!passwordField) continue;

		autoCheckbox.addEventListener('change', () => manuallySet.add(autoCheckbox));

		const updateCheckbox = () => {
			if (!manuallySet.has(autoCheckbox))
				autoCheckbox.checked = passwordField.value !== '' || passwordSelect.value !== '';
		};

		passwordField.addEventListener('input', updateCheckbox);
		passwordSelect.addEventListener('change', updateCheckbox);
		updateCheckbox();
	}
})();
