// Javascript for gateway tests.
//
// This file includes the routines allowing navigation within gateway tests, manages the timer, and posts alerts when
// test time is winding up.
//
// The timer code relies on the existence of data attributes for the gwTimer div created by GatewayQuiz.pm.

(() => {
	if (!document.gwquiz) return;

	// Gateway timer
	const timerDiv = document.getElementById('gwTimer'); // The timer div element
	let actuallySubmit = false; // This needs to be set to true to allow an actual submission.
	// The 'Grade Test' submit button.
	const submitAnswers =
		document.gwquiz.elements.submitAnswers instanceof NodeList
			? document.gwquiz.elements.submitAnswers[document.gwquiz.elements.submitAnswers.length - 1]
			: document.gwquiz.elements.submitAnswers;
	let timeDelta; // The difference between the browser time and the server time
	let serverDueTime; // The time the test is due
	let gracePeriod; // The grace period
	let remainingTimeString = timerDiv?.textContent.replace('00:00:00', '');

	// Convert seconds to hh:mm:ss format
	const formatTime = (t) => {
		// Don't deal with negative times.
		if (t < 0) t = 0;
		const date = new Date(0);
		date.setSeconds(t);
		return date.toISOString().substring(11, 19);
	};

	const alertToast = (message, delay = 5000) => {
		const toastContainer = document.createElement('div');
		toastContainer.classList.add(
			'gwAlert',
			'toast-container',
			'position-fixed',
			'top-0',
			'start-50',
			'translate-middle-x',
			'p-3'
		);
		toastContainer.innerHTML =
			'<div class="toast bg-white" role="alert" aria-live="assertive" aria-atomic="true">' +
			'<div class="toast-header">' +
			`<strong class="me-auto">${timerDiv.dataset.alertTitle ?? 'Test Time Notification'}</strong>` +
			'<button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="close"></button>' +
			'</div>' +
			`<div class="toast-body alert alert-danger mb-0 text-center">${message}</div>` +
			'</div>';
		document.body.prepend(toastContainer);
		const bsToast = new bootstrap.Toast(toastContainer.firstElementChild, { delay });
		toastContainer.addEventListener('hidden.bs.toast', () => {
			bsToast.dispose();
			toastContainer.remove();
		});
		bsToast.show();
	};

	// Update the timer
	const updateTimer = () => {
		const dateNow = new Date();
		const browserTime = Math.round(dateNow.getTime() / 1000);
		const remainingTime = serverDueTime - browserTime + timeDelta;

		// Set the timer text.
		if (remainingTime >= 0) {
			timerDiv.textContent = `${remainingTimeString}${formatTime(remainingTime)}`;
		} else {
			timerDiv.textContent = `${remainingTimeString}00:00:00`;
		}

		if (!timerDiv.dataset.acting) {
			// Check to see if we should put up a low time alert, or submit the test if
			// the time is near the end of the grace period.
			const alertStatus = sessionStorage.getItem('gatewayAlertStatus');

			if (remainingTime <= 10 - gracePeriod) {
				if (!alertStatus) return;
				sessionStorage.removeItem('gatewayAlertStatus');
				actuallySubmit = true;
				submitAnswers.click();
			} else if (remainingTime > 10 - gracePeriod && remainingTime <= 0) {
				if (alertStatus !== '1') {
					alertToast(
						timerDiv.dataset.alertOne ??
							'<div>You are out of time!</div><div>Press "Grade Test" now!</div>',
						(remainingTime + gracePeriod) * 1000
					);
					sessionStorage.setItem('gatewayAlertStatus', '1');
				}
			} else if (remainingTime > 0 && remainingTime <= 45) {
				if (alertStatus !== '2') {
					alertToast(
						timerDiv.dataset.alertTwo ??
							'<div>You have less than 45 seconds left!</div><div>Press "Grade Test" soon!</div>',
						remainingTime * 1000
					);
					sessionStorage.setItem('gatewayAlertStatus', '2');
				}
			} else if (remainingTime > 45 && remainingTime <= 90) {
				if (alertStatus !== '3') {
					alertToast(
						timerDiv.dataset.alertThree ??
							'You have less than 90 seconds left to complete this assignment. You should finish it soon!',
						(remainingTime - 45) * 1000
					);
					sessionStorage.setItem('gatewayAlertStatus', '3');
				}
			}
		}
	};

	const basicWebserviceURL = `${webworkConfig?.webwork_url ?? '/webwork2'}/instructor_rpc`;

	const updateTimeDelta = async () => {
		const authenParams = {};
		const user = document.getElementsByName('user')[0];
		if (user) authenParams.user = user.value;
		const sessionKey = document.getElementsByName('key')[0];
		if (sessionKey) authenParams.key = sessionKey.value;

		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), 10000);

		const response = await fetch(basicWebserviceURL, {
			method: 'post',
			mode: 'same-origin',
			body: new URLSearchParams({
				...authenParams,
				rpc_command: 'getCurrentServerTime',
				courseID: timerDiv.dataset.courseId
			}),
			signal: controller.signal
		}).catch(() => {
			/* Errors are ignored */
		});

		clearTimeout(timeoutId);

		if (response && response.ok) {
			const data = await response.json();
			timeDelta = Math.round(new Date().getTime() / 1000) - data.result_data.currentServerTime;
		}
	};

	if (timerDiv) {
		// Initialize the time variables and start the timer.
		const dateNow = new Date();
		const browserTime = Math.round(dateNow.getTime() / 1000);
		serverDueTime = parseInt(timerDiv.dataset.serverDueTime);
		timeDelta = browserTime - parseInt(timerDiv.dataset.serverTime);
		gracePeriod = parseInt(timerDiv.dataset.gracePeriod);

		updateTimeDelta();
		setInterval(updateTimeDelta, Math.min((parseInt(timerDiv.dataset.sessionTimeout) - 60) * 1000, 2147483646));

		const remainingTime = serverDueTime - browserTime + timeDelta;

		if (!timerDiv.dataset.acting && remainingTime <= 10 - gracePeriod) {
			if (sessionStorage.getItem('gatewayAlertStatus')) {
				sessionStorage.removeItem('gatewayAlertStatus');

				// Submit the test if time is expired and near the end of grace period.
				actuallySubmit = true;
				submitAnswers.click();
			}
		} else {
			// Set the timer text and check alerts at page load.
			updateTimer();

			// Start the timer.
			setInterval(updateTimer, 1000);
		}
	}

	// Show a confirmation dialog when a student clicks 'Grade Test'.
	if (typeof submitAnswers?.dataset?.confirmDialogMessage !== 'undefined') {
		submitAnswers.addEventListener('click', (evt) => {
			// Don't show the dialog if the test is timed and in the last 90 seconds.
			// The alerts above are now being shown telling the student to submit the test.
			if (
				typeof serverDueTime !== 'undefined' &&
				serverDueTime - Math.round(new Date().getTime() / 1000) + timeDelta < 90
			)
				return;

			if (actuallySubmit) return;

			const inputs = Array.from(document.querySelectorAll('input, select'));

			// All problem numbers are represented by a probstatus hidden input. Use those to determine the problem
			// numbers of problems in the test. Note that problem numbering displayed on the page will not match these
			// numbers in the cases that the test definition has non-consecutive numbering or that problem order is
			// randomized. But the problem numbering will always match the quiz prefix numbering.
			const problems = [];
			for (const input of inputs.filter((i) => /^probstatus\d*/.test(i.name))) {
				problems[parseInt(input.name.replace('probstatus', ''))] = {};
			}

			// Determine which questions have been answered.  Note that there can be multiple inputs for a
			// given question (for example for checkbox or radio answers).
			for (const input of inputs.filter(
				(i) => /Q\d{4}_/.test(i.name) && !/^MaThQuIlL_/.test(i.name) && !/^previous_/.test(i.name)
			)) {
				const answered =
					input.type === 'radio' || input.type === 'checkbox' ? !!input.checked : /\S/.test(input.value);
				const match = /Q(\d{4})_/.exec(input.name);
				const problemNumber = parseInt(match?.[1] ?? '0');
				if (!(input.name in problems[problemNumber])) problems[problemNumber][input.name] = answered;
				else if (answered) problems[problemNumber][input.name] = 1;
			}

			// Determine if there are any unanswered questions in each problem.
			let numProblemsWithUnanswered = 0;
			for (const problem of problems) {
				// Skip problem 0 and any problems that don't exist in the test
				// due to non-consecutive numbering in the test definition.
				if (!problem) continue;

				if (!Object.keys(problem).length || !Object.values(problem).every((answered) => answered))
					++numProblemsWithUnanswered;
			}

			// Prevent the gwquiz form from being submitted until after confirmation.
			evt.preventDefault();

			const modal = document.createElement('div');
			modal.classList.add('modal');
			modal.tabIndex = -1;
			modal.setAttribute('aria-labelledby', 'gwquiz-confirm-submit-dialog');
			modal.setAttribute('aria-hidden', 'true');

			const modalDialog = document.createElement('div');
			modalDialog.classList.add('modal-dialog', 'modal-dialog-centered');
			const modalContent = document.createElement('div');
			modalContent.classList.add('modal-content');

			const modalHeader = document.createElement('div');
			modalHeader.classList.add('modal-header');

			const title = document.createElement('h5');
			title.id = 'gwquiz-confirm-submit-dialog';
			title.textContent = submitAnswers.dataset.confirmDialogTitle ?? 'Do you want to grade this test?';

			const closeButton = document.createElement('button');
			closeButton.type = 'button';
			closeButton.classList.add('btn-close');
			closeButton.dataset.bsDismiss = 'modal';
			closeButton.setAttribute('aria-label', 'close');

			modalHeader.append(title, closeButton);

			const modalBody = document.createElement('div');
			modalBody.classList.add('modal-body');

			if (numProblemsWithUnanswered) {
				const modalSecondaryContent = document.createElement('div');
				modalSecondaryContent.classList.add('mb-3');
				modalSecondaryContent.textContent =
					(numProblemsWithUnanswered > 1
						? submitAnswers.dataset.unansweredQuestionsMessage
							? submitAnswers.dataset.unansweredQuestionsMessage.replace('%d', numProblemsWithUnanswered)
							: `There are ${numProblemsWithUnanswered} problems with unanswered questions.`
						: (submitAnswers.dataset.unansweredQuestionMessage ??
							'There is a problem with unanswered questions.')) +
					' ' +
					(submitAnswers.dataset.returnToTestMessage ??
						'Are you sure you want to grade the test? ' +
							'Select "No" if you would like to return to the test to enter more answers.');
				modalBody.append(modalSecondaryContent);
			}

			const modalBodyContent = document.createElement('div');
			modalBodyContent.textContent = submitAnswers.dataset.confirmDialogMessage;
			modalBody.append(modalBodyContent);

			const modalFooter = document.createElement('div');
			modalFooter.classList.add('modal-footer');

			const yesButton = document.createElement('button');
			yesButton.classList.add('btn', 'btn-primary');
			yesButton.textContent = submitAnswers.dataset.confirmBtnText ?? 'Yes';
			yesButton.addEventListener('click', () => {
				// The student has clicked yes, so now submit the gwquiz form.
				actuallySubmit = true;
				submitAnswers.click();
				bsModal.hide();
			});

			const noButton = document.createElement('button');
			noButton.classList.add('btn', 'btn-primary');
			noButton.dataset.bsDismiss = 'modal';
			noButton.textContent = submitAnswers.dataset.cancelBtnText ?? 'No';

			modalFooter.append(yesButton, noButton);
			modalContent.append(modalHeader, modalBody, modalFooter);
			modalDialog.append(modalContent);
			modal.append(modalDialog);

			const bsModal = new bootstrap.Modal(modal);
			bsModal.show();
			modal.addEventListener('hidden.bs.modal', () => {
				bsModal.dispose();
				modal.remove();
			});
		});
	}

	// Set up the preview buttons.
	document.querySelectorAll('.gateway-preview-btn').forEach((btn) => {
		btn.addEventListener('click', (evt) => {
			// Prevent the link from being followed.
			evt.preventDefault();
			if (btn.dataset.currentPage) document.gwquiz.newPage.value = btn.dataset.currentPage;
			document.gwquiz.previewAnswers.click();
		});
	});

	// Scroll to a problem when the problem number link is clicked.
	document.querySelectorAll('.problem-jump-link').forEach((jumpLink) => {
		jumpLink.addEventListener('click', (evt) => {
			// Prevent the link from being followed.
			evt.preventDefault();
			if (jumpLink.dataset.problemNumber) {
				// Note that the anchor indexing starts at 0, not 1.
				const problem = document.getElementById(`prob${parseInt(jumpLink.dataset.problemNumber) - 1}`);
				problem.focus();
				problem.scrollIntoView({ behavior: 'smooth' });
			}
		});
	});

	// Change pages when a page change link is clicked.
	document.querySelectorAll('.page-change-link').forEach((pageChangeLink) => {
		pageChangeLink.addEventListener('click', (evt) => {
			// Prevent the link from being followed.
			evt.preventDefault();
			document.gwquiz.pageChangeHack.value = 1;
			document.gwquiz.newPage.value = pageChangeLink.dataset.pageNumber;
			document.gwquiz.previewAnswers.click();
		});
	});

	// Show any achievement toasts if there are any.
	document.querySelectorAll('.cheevo-toast').forEach((toast) => {
		const bsToast = new bootstrap.Toast(toast, { delay: 5000 });
		bsToast.show();
	});

	// Periodically save answers on timed tests by submitting the form in the background as a preview request.  The
	// server saves the last answers for preview requests, so this ensures that the work of a student whose session is
	// interrupted (for example, by a computer crash or dropped connection) is not lost.  This is disabled by default,
	// and is enabled by setting $gatewayAutosaveInterval in the course environment.  If enabled, the template provides
	// the gw-autosave-status element with the configured interval.  This is not done when an instructor is acting as
	// another user, so that the student's stored answers are not unintentionally modified.
	const autosaveStatus = document.getElementById('gw-autosave-status');
	const autosaveInterval = 1000 * (parseInt(autosaveStatus?.dataset.interval ?? '') || 0);
	if (timerDiv && !timerDiv.dataset.acting && autosaveInterval > 0 && document.gwquiz.elements.previewAnswers) {
		const serializeAnswers = () => {
			const formData = new URLSearchParams(new FormData(document.gwquiz));
			// Submit buttons are not included in the FormData object, so the previewAnswers parameter must be
			// added.  The server only checks that the parameter has a true value to treat the request as a preview.
			// Since no submit button parameters are included, the request cannot grade the test or change pages.
			formData.set('previewAnswers', '1');
			return formData;
		};

		let lastSavedAnswers = serializeAnswers().toString();

		const autosave = async () => {
			const formData = serializeAnswers();

			// Only save if the answers have changed since the last successful save.
			if (formData.toString() === lastSavedAnswers) return;

			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), 10000);

			const response = await fetch(document.gwquiz.getAttribute('action'), {
				method: 'post',
				mode: 'same-origin',
				body: formData,
				signal: controller.signal
			}).catch(() => {
				/* Errors are handled below. */
			});

			clearTimeout(timeoutId);

			let saved = false;
			if (response && response.ok) {
				const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
				// If the session was lost, then the response is a login page that does not contain the gwquiz form.
				if (doc.querySelector('form[name="gwquiz"]')) saved = true;
			}

			if (saved) {
				lastSavedAnswers = formData.toString();
				autosaveStatus.textContent = autosaveStatus.dataset.successMessage.replace(
					'{time}',
					new Date().toLocaleTimeString()
				);
				autosaveStatus.classList.remove('d-none', 'alert', 'alert-danger');
				autosaveStatus.classList.add('small', 'text-muted');
			} else {
				autosaveStatus.textContent = autosaveStatus.dataset.errorMessage;
				autosaveStatus.classList.remove('d-none', 'small', 'text-muted');
				autosaveStatus.classList.add('alert', 'alert-danger');
			}
		};

		// Randomize the interval by up to a third to stagger the autosave load from a class full of students
		// that all start a test at the same time.
		setInterval(autosave, autosaveInterval + Math.floor((Math.random() * autosaveInterval) / 3));
	}
})();
