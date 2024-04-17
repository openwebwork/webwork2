(() => {
	const configForm = document.getElementById('config-form');
	if (!configForm) return;

	const elementInitialValues = [];
	for (const element of configForm.elements) {
		elementInitialValues.push([element, element.type === 'checkbox' ? element.checked : element.value]);
	}

	window.onbeforeunload = () => {
		for (const [element, initialValue] of elementInitialValues) {
			if (
				(element.type === 'checkbox' && element.checked !== initialValue) ||
				(element.type !== 'checkbox' && element.value !== initialValue)
			)
				return true;
		}
	};

	configForm.addEventListener('submit', () => (window.onbeforeunload = null));
})();
