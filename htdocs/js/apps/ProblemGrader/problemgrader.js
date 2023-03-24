'use strict';

(() => {
	// Comment preview popovers.
	document.querySelectorAll('.preview').forEach((el) => {
		el.addEventListener('click', () => {
			el.dataset.bsContent =
				el.parentNode.querySelector('textarea')?.value.replace(/</g, '< ').replace(/>/g, ' >');
			if (el.dataset.bsContent) {
				const popover = new bootstrap.Popover(el, {
					html: true, trigger: 'focus', placement: 'bottom', delay: { show: 0, hide: 200 }
				});
				el.addEventListener('hidden.bs.popover', () => popover.dispose(), { once: true });
				popover.show();
				if (window.MathJax) {
					MathJax.startup.promise = MathJax.startup.promise.then(
						() => MathJax.typesetPromise(['.popover-body'])
					);
				}
			}
		});
	});

	const setPointInputValue = (pointInput, score) =>
		pointInput.value = (Math.round(score * pointInput.max / 100 / pointInput.step) * pointInput.step).toFixed(2);

	// Compute the problem score from any answer sub scores, and update the problem score input.
	document.querySelectorAll('.answer-part-score').forEach((part) => {
		part.addEventListener('input', () => {
			const problemId = part.dataset.problemId;
			const answerLabels = JSON.parse(part.dataset.answerLabels);

			if (!part.checkValidity()) {
				part.classList.add('is-invalid');
			} else {
				part.classList.remove('is-invalid');

				let score = 0;
				answerLabels.forEach((label) => {
					const partElt = document.getElementById(`score_problem${problemId}_${label}`);
					score += partElt.value * partElt.dataset.weight;
				});
				document.getElementById(`score_problem${problemId}`).value = Math.round(score);

				const pointInput = document.getElementById(`score_problem${problemId}_points`);
				if (pointInput) setPointInputValue(pointInput, score);
			}
			document.getElementById(`grader_messages_problem${problemId}`).innerHTML = '';
		});
	});

	// Update problem score if point value changes and is a valid value.
	document.querySelectorAll('.problem-points').forEach((pointInput) => {
		pointInput.addEventListener('input', () => {
			const problemId = pointInput.dataset.problemId;
			if (pointInput.checkValidity()) {
				const scoreInput = document.getElementById(`score_problem${problemId}`);
				pointInput.classList.remove('is-invalid');
				scoreInput.classList.remove('is-invalid');
				scoreInput.value = Math.round(100 * pointInput.value / pointInput.max);
			} else {
				pointInput.classList.add('is-invalid');
			}
			document.getElementById(`grader_messages_problem${problemId}`).innerHTML = '';
		});
	});

	// Clear messages when the score or comment are changed.
	document.querySelectorAll('.problem-score,.grader-problem-comment').forEach((el) => {
		el.addEventListener('input', () => {
			const problemId = el.dataset.problemId;
			if (!el.checkValidity()) {
				el.classList.add('is-invalid');
			} else {
				el.classList.remove('is-invalid');

				if (el.classList.contains('problem-score')) {
					const pointInput = document.getElementById(`score_problem${problemId}_points`);
					if (pointInput) {
						pointInput.classList.remove('is-invalid');
						setPointInputValue(pointInput, el.value);
					}
				}
			}
			document.getElementById(`grader_messages_problem${el.dataset.problemId}`).innerHTML = '';
		});
	});

	// Save the score and comment.
	document.querySelectorAll('.save-grade').forEach((saveButton) => {
		saveButton.addEventListener('click', async () => {
			const saveData = saveButton.dataset;

			const user = document.getElementById('hidden_user').value;
			const sessionKey = document.getElementById('hidden_key').value;

			const messageArea = document.getElementById(`grader_messages_problem${saveData.problemId}`);

			const scoreInput = document.getElementById('score_problem' + saveData.problemId);
			if (!scoreInput.checkValidity()) {
				messageArea.classList.add('alert-danger');
				messageArea.textContent = scoreInput.validationMessage;
				setTimeout(() => messageArea.classList.remove('alert-danger'), 100);
				scoreInput.focus();
				return;
			}

			// Save the score.
			const basicWebserviceURL = `${webworkConfig?.webwork_url ?? '/webwork2'}/instructor_rpc`;

			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), 10000);

			try {
				const response = await fetch(basicWebserviceURL, {
					method: 'post',
					mode: 'same-origin',
					body: new URLSearchParams({
						user: user,
						key: sessionKey,
						rpc_command: saveData.versionId !== '0' ? 'putProblemVersion' : 'putUserProblem',
						courseID: saveData.courseId,
						user_id: saveData.studentId,
						set_id: saveData.setId,
						version_id: saveData.versionId,
						problem_id: saveData.problemId,
						status: parseInt(scoreInput.value) / 100
					}),
					signal: controller.signal
				});

				clearTimeout(timeoutId);

				if (!response.ok) {
					throw 'Unknown server communication error.';
				} else {
					const data = await response.json();
					if (data.error) {
						throw data.error;
					} else {
						// Update the hidden problem status fields and score table for gateway quizzes
						if (saveData.versionId !== '0') {
							document.gwquiz.elements['probstatus' + saveData.problemId].value =
								parseInt(scoreInput.value) / 100;
							let testValue = 0;
							for (const scoreCell of document.querySelectorAll('table.gwNavigation td.score')) {
								if (scoreCell.dataset.problemId == saveData.problemId) {
									scoreCell.textContent = scoreInput.value == '100' ? '\u{1F4AF}' : scoreInput.value;
								}
								testValue += document.gwquiz.elements['probstatus'
									+ scoreCell.dataset.problemId].value * scoreCell.dataset.problemValue;
							}
							const recordedScore = document.getElementById('test-recorded-score');
							if (recordedScore) {
								recordedScore.textContent = Math.round(100 * testValue / 2) / 100;
								document.getElementById('test-recorded-percent').textContent =
									Math.round(100 * testValue /
										(2 * document.getElementById('test-total-possible').textContent));
							}
						}

						if (saveData.pastAnswerId !== '0') {
							// Save the comment.
							const comment = document.getElementById(`comment_problem${saveData.problemId}`)?.value;

							const controller = new AbortController();
							const timeoutId = setTimeout(() => controller.abort(), 10000);

							try {
								const response = await fetch(basicWebserviceURL, {
									method: 'post',
									body: new URLSearchParams({
										user: user,
										key: sessionKey,
										rpc_command: 'putPastAnswer',
										courseID: saveData.courseId,
										answer_id: saveData.pastAnswerId,
										comment_string: comment
									}),
									signal: controller.signal
								});

								clearTimeout(timeoutId);

								if (!response.ok) {
									throw 'Unknown server communication error.';
								} else {
									const data = await response.json();
									if (data.error) {
										throw data.error;
									} else {
										messageArea.classList.add('alert-success');
										messageArea.textContent = 'Score and comment saved.';
										setTimeout(() => messageArea.classList.remove('alert-success'), 100);
									}
								}
							} catch (e) {
								messageArea.classList.add('alert-danger');
								messageArea.innerHTML =
									'<div>The score was saved, but there was an error saving the comment.</div>' +
									`<div>${e}</div>`;
								setTimeout(() => messageArea.classList.remove('alert-danger', 100));
							}
						} else {
							messageArea.classList.add('alert-success');
							messageArea.textContent = 'Score saved.';
							setTimeout(() => messageArea.classList.remove('alert-success'), 100);
						}
					}
				}
			} catch (e) {
				messageArea.classList.add('alert-danger');
				messageArea.innerHTML = `<div>Error saving score.</div><div>${e?.message ?? e}</div>`;
				setTimeout(() => messageArea.classList.remove('alert-danger', 100));
			}
		});
	})

	// Problem rendering.

	const userSelect = document.getElementById('student_selector');
	if (!userSelect) return;

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
