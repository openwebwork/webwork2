(() => {
	const container = document.getElementById('problemMainForm');
	const storeId = 'wwStickyAnswers';

	const identifier = (document.querySelector("input[name='problemUUID']")?.value ?? '') +
		(document.querySelector("input[name='sourceFilePath']")?.value ?? '') +
		(document.querySelector("input[name='problemSource']")?.value ?? '') +
		(document.querySelector("input[name='problemSeed']")?.value ?? '');

	if (identifier === '') return;

	const storedData = localStorage.getItem(storeId);
	const store = storedData ? JSON.parse(storedData) : {};
	const problemData = store[identifier] ? store[identifier] : {};

	const storeData = function () {
		if (!problemData.inputs) problemData.inputs = {};

		container.querySelectorAll('input').forEach((input) => {
			if (input.type && input.type.toUpperCase() == 'RADIO') {
				if (input.checked) problemData.inputs[input.name] = input.value;
			} else if (/AnSwEr/.test(input.name)) {
				problemData.inputs[input.name] = input.value;
			}
		});

		store[identifier] = problemData;
		localStorage.setItem(storeId, JSON.stringify(store));
	}

	container.addEventListener('submit', storeData);

	if (problemData) {
		if (problemData.inputs) {
			const keys = Object.keys(problemData.inputs);

			keys.forEach(function (key) {
				container.querySelectorAll(`[name="${key}"]`).forEach((input) => {
					if (input.type && input.type.toUpperCase() === 'RADIO') {
						if (input.value === problemData.inputs[key]) input.checked = true;
					} else {
						input.value = problemData.inputs[key];
					}
				});
			});
		}

		const resultScore = document.getElementById('problem-result-score');
		if (resultScore) {
			if (!problemData['score'] || problemData['score'] < resultScore.value) {
				problemData['score'] = resultScore.value;
				store[identifier] = problemData;
				localStorage.setItem(storeId, JSON.stringify(store));
			}
		}

		const overallScore = document.getElementById('problem-overall-score');
		if (overallScore)
			overallScore.textContent = problemData['score'] ? `${Math.round(problemData['score'] * 100)}%` : '0%';
	}
})();
