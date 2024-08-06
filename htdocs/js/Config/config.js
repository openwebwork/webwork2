(() => {
	const configForm = document.getElementById('config-form');
	if (!configForm) return;

	const elementInitialValues = [];
	for (const element of configForm.elements) {
		if (element.name === 'current_tab') continue;
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

	if (configForm.current_tab) {
		document.querySelectorAll('.tab-link').forEach((tabLink) => {
			tabLink.addEventListener('show.bs.tab', () => (configForm.current_tab.value = tabLink.dataset.tab));
		});
	}
})();
