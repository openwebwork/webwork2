'use strict';

(() => {
	const setPointInputValue = (pointInput, score) =>
		(pointInput.value = parseFloat(
			(Math.round((score * pointInput.max) / 100 / pointInput.step) * pointInput.step).toFixed(2)
		));

	// Update problem score if point value changes and is a valid value.
	for (const pointInput of document.querySelectorAll('.problem-points')) {
		pointInput.addEventListener('input', () => {
			const userId = pointInput.id.replace(/\.points$/, '');
			if (pointInput.checkValidity()) {
				const scoreInput = document.getElementById(`${userId}.score`);
				if (scoreInput) {
					scoreInput.classList.remove('is-invalid');
					scoreInput.value = Math.round((100 * pointInput.value) / pointInput.max);
				}
				pointInput.classList.remove('is-invalid');
			} else {
				pointInput.classList.add('is-invalid');
			}
		});
	}

	// Update problem points if score changes and is a valid value.
	for (const scoreInput of document.querySelectorAll('.problem-score')) {
		scoreInput.addEventListener('input', () => {
			const userId = scoreInput.id.replace(/\.score$/, '');
			if (scoreInput.checkValidity()) {
				const pointInput = document.getElementById(`${userId}.points`);
				if (pointInput) {
					pointInput.classList.remove('is-invalid');
					pointInput.value = setPointInputValue(pointInput, scoreInput.value);
				}
				scoreInput.classList.remove('is-invalid');
			} else {
				scoreInput.classList.add('is-invalid');
			}
		});
	}

	const userSelect = document.getElementById('student_selector');
	if (!userSelect) return;

	// Problem rendering.
	const render = () => {
		const selectedUser = userSelect.options[userSelect.selectedIndex];
		if (!selectedUser) return;

		const ro = {
			effectiveUser: userSelect.value,
			sourceFilePath: selectedUser.dataset.sourceFile,
			problemSeed: selectedUser.dataset.problemSeed,
			set_id: document.getElementsByName('hidden_set_id')[0]?.value,
			probNum: document.getElementsByName('hidden_problem_id')[0]?.value,
			processAnswers: 1,
			WWcorrectAns: 1
		};

		if (selectedUser.dataset.versionId) ro.version_id = selectedUser.dataset.versionId;
		if (selectedUser.dataset.answerPrefix) ro.answerPrefix = selectedUser.dataset.answerPrefix;

		if (selectedUser.dataset.lastAnswer) {
			for (const [label, answer] of Object.entries(
				JSON.parse(selectedUser.dataset.lastAnswer).reduce((acc, o, i, arr) => {
					if (i % 2 === 0) acc[o] = arr[i + 1];
					return acc;
				}, {})
			)) {
				if (answer !== null) ro[label] = answer;
			}
		}

		let haveAltSource = false;
		for (const answers of document.querySelectorAll('.problem-answers')) {
			if (answers.dataset.sourceFile !== selectedUser.dataset.sourceFile) {
				haveAltSource = true;
				answers.classList.add('alt-source');
			} else {
				answers.classList.remove('alt-source');
			}
		}
		if (haveAltSource) document.getElementById('alt-source-key')?.classList.remove('d-none');
		else document.getElementById('alt-source-key')?.classList.add('d-none');

		webworkConfig.renderProblem('problem_render_area', ro);
	};

	// Initial render on page load.
	render();

	// Re-render when a new student/version or display mode is selected.
	userSelect.addEventListener('change', render);
	document.getElementById('problem_displaymode')?.addEventListener('change', render);
})();
