'use strict';

(() => {
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
			processAnswers: 1
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
