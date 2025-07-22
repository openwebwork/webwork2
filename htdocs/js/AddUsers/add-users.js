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
})();
