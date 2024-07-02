'use strict';

(() => {
	const setPointInputValue = (pointInput, score) =>
		(pointInput.value = parseFloat(
			(Math.round((score * pointInput.max) / 100 / pointInput.step) * pointInput.step).toFixed(2)
		));

	// Compute the problem score from any answer sub scores, and update the problem score input.
	for (const part of document.querySelectorAll('.answer-part-score')) {
		part.addEventListener('input', () => {
			const problemId = part.dataset.problemId;
			const answerLabels = JSON.parse(part.dataset.answerLabels);

			if (!part.checkValidity()) {
				part.classList.add('is-invalid');
			} else {
				part.classList.remove('is-invalid');

				let score = 0;
				for (const label of answerLabels) {
					const partElt = document.getElementById(`score_problem${problemId}_${label}`);
					score += partElt.value * partElt.dataset.weight;
				}
				document.getElementById(`score_problem${problemId}`).value = Math.round(score);

				const pointInput = document.getElementById(`score_problem${problemId}_points`);
				if (pointInput) setPointInputValue(pointInput, score);
			}
			document.getElementById(`grader_messages_problem${problemId}`).innerHTML = '';
		});
	}

	// Update problem score if point value changes and is a valid value.
	for (const pointInput of document.querySelectorAll('.problem-points')) {
		pointInput.addEventListener('input', () => {
			const problemId = pointInput.dataset.problemId;
			if (pointInput.checkValidity()) {
				const scoreInput = document.getElementById(`score_problem${problemId}`);
				pointInput.classList.remove('is-invalid');
				scoreInput.classList.remove('is-invalid');
				scoreInput.value = Math.round((100 * pointInput.value) / pointInput.max);
			} else {
				pointInput.classList.add('is-invalid');
			}
			document.getElementById(`grader_messages_problem${problemId}`).innerHTML = '';
		});
	}

	// Clear messages when the score or comment are changed.
	for (const el of document.querySelectorAll('.problem-score,.grader-problem-comment')) {
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
	}

	// Recompute the problem score from the scores for the last checked answers.
	for (const recomputeBtn of document.querySelectorAll('.recompute-grade')) {
		const problemId = recomputeBtn.dataset.problemId;

		let currentScore = 0;
		for (const part of document.querySelectorAll(`.answer-part-score[data-problem-id="${problemId}"]`)) {
			currentScore += part.value * part.dataset.weight;
		}

		recomputeBtn.addEventListener('click', () => {
			document.getElementById(`score_problem${problemId}`).value = Math.round(currentScore);
			const pointInput = document.getElementById(`score_problem${problemId}_points`);
			if (pointInput) setPointInputValue(pointInput, currentScore);
		});
	}

	// Save the score and comment.
	for (const saveButton of document.querySelectorAll('.save-grade')) {
		saveButton.addEventListener('click', async () => {
			const saveData = saveButton.dataset;

			const authenParams = {};
			const user = document.getElementsByName('user')[0];
			if (user) authenParams.user = user.value;
			const sessionKey = document.getElementsByName('key')[0];
			if (sessionKey) authenParams.key = sessionKey.value;

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
						...authenParams,
						rpc_command: saveData.versionId !== '0' ? 'putProblemVersion' : 'putUserProblem',
						courseID: saveData.courseId,
						user_id: saveData.studentId,
						set_id: saveData.setId,
						version_id: saveData.versionId,
						problem_id: saveData.problemId,
						status: parseInt(scoreInput.value) / 100,
						mark_graded: true
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
							const probStatus = document.gwquiz.elements[`probstatus${saveData.problemId}`];
							if (probStatus) probStatus.value = parseInt(scoreInput.value) / 100;
							let testValue = 0;
							for (const scoreCell of document.querySelectorAll('table.gwNavigation td.score')) {
								if (scoreCell.dataset.problemId == saveData.problemId) {
									scoreCell.textContent = scoreInput.value == '100' ? '\u{1F4AF}' : scoreInput.value;
								}
								testValue +=
									(document.gwquiz.elements[`probstatus${scoreCell.dataset.problemId}`]?.value ?? 0) *
									scoreCell.dataset.problemValue;
							}
							const recordedScore = document.getElementById('test-recorded-score');
							if (recordedScore) {
								recordedScore.textContent = Math.round((100 * testValue) / 2) / 100;
								document.getElementById('test-recorded-percent').textContent = Math.round(
									(100 * testValue) / (2 * document.getElementById('test-total-possible').textContent)
								);
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
										...authenParams,
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
								setTimeout(() => messageArea.classList.remove('alert-danger'), 100);
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
				setTimeout(() => messageArea.classList.remove('alert-danger'), 100);
			}
		});
	}
})();
