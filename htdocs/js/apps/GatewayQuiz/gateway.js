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
	const submitAnswers = document.gwquiz.elements.submitAnswers instanceof NodeList
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
			'gwAlert', 'toast-container', 'position-fixed', 'top-0', 'start-50',  'translate-middle-x', 'p-3');
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
		toastContainer.addEventListener('hidden.bs.toast', () => { bsToast.dispose(); toastContainer.remove(); })
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
					alertToast(timerDiv.dataset.alertOne ??
						'<div>You are out of time!</div><div>Press "Grade Test" now!</div>',
						(remainingTime + gracePeriod) * 1000);
					sessionStorage.setItem('gatewayAlertStatus', '1');
				}
			} else if (remainingTime > 0 && remainingTime <= 45) {
				if (alertStatus !== '2') {
					alertToast(timerDiv.dataset.alertTwo ??
						'<div>You have less than 45 seconds left!</div><div>Press "Grade Test" soon!</div>',
						remainingTime * 1000);
					sessionStorage.setItem('gatewayAlertStatus', '2');
				}
			} else if (remainingTime > 45 && remainingTime <= 90) {
				if (alertStatus !== '3') {
					alertToast(timerDiv.dataset.alertThree ??
						'You have less than 90 seconds left to complete this assignment. You should finish it soon!',
						(remainingTime - 45) * 1000);
					sessionStorage.setItem('gatewayAlertStatus', '3');
				}
			}
		}
	};

	if (timerDiv) {
		// Initialize the time variables and start the timer.
		const dateNow = new Date();
		const browserTime = Math.round(dateNow.getTime() / 1000);
		serverDueTime = parseInt(timerDiv.dataset.serverDueTime);
		timeDelta = browserTime - parseInt(timerDiv.dataset.serverTime);
		gracePeriod = parseInt(timerDiv.dataset.gracePeriod);

		const remainingTime = serverDueTime - browserTime + timeDelta;

		if (!timerDiv.dataset.acting) {
			if (remainingTime <= 10 - gracePeriod) {
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
	};

	// Show a confirmation dialog when a student clicks 'Grade Test'.
	if (typeof submitAnswers?.dataset?.confirmDialogMessage !== 'undefined') {
		submitAnswers.addEventListener('click', (evt) => {
			// Don't show the dialog if the test is timed and in the last 90 seconds.
			// The alerts above are now being shown telling the student to submit the test.
			if (typeof serverDueTime !== 'undefined' &&
				serverDueTime - Math.round(new Date().getTime() / 1000) + timeDelta < 90)
				return;

			if (actuallySubmit) return;

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
			modal.addEventListener('hidden.bs.modal', () => { bsModal.dispose(); modal.remove(); });
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
			evt.preventDefault()
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
})();
