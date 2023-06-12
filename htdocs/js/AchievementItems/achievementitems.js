(() => {
	for (const setSelect of document.querySelectorAll('select[data-problems]')) {
		setSelect.addEventListener('change', () => {
			const max = parseInt(Array.from(setSelect.querySelectorAll('option'))
				.find((option) => option.value === setSelect.value)?.dataset.max ?? '0');

			document.querySelectorAll(`#${setSelect.dataset.problems} option`).forEach((option, index) => {
				option.style.display = index < max ? '' : 'none';
			});

			// This is only used by the "Box of Transmogrification".
			document.querySelectorAll(`#${setSelect.dataset.problems2} option`).forEach((option, index) => {
				option.style.display = index < max ? '' : 'none';
			});
		});
	}
})();
