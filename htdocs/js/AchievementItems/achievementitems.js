(() => {
	for (const setSelect of document.querySelectorAll('select[data-problems]')) {
		setSelect.addEventListener('change', () => {
			const problemIds = JSON.parse(
				Array.from(setSelect.querySelectorAll('option')).find((option) => option.value === setSelect.value)
					?.dataset.problemIds ?? '[]'
			);

			const problemSelect = document.getElementById(setSelect.dataset.problems);
			if (problemSelect) {
				for (const option of problemSelect.querySelectorAll('option')) option.remove();
				for (const id of problemIds) {
					const option = document.createElement('option');
					option.value = id;
					option.text = id;
					problemSelect.add(option);
				}
			}

			// This is only used by the "Box of Transmogrification".
			const problemSelect2 = document.getElementById(setSelect.dataset.problems2);
			if (problemSelect2) {
				for (const option of problemSelect2.querySelectorAll('option')) option.remove();
				for (const id of problemIds) {
					const option = document.createElement('option');
					option.value = id;
					option.text = id;
					problemSelect2.add(option);
				}
			}
		});
	}
})();
