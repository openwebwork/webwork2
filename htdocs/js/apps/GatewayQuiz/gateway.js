// Javascript for gateway tests.
//
// This file includes the routines allowing navigation within gateway tests, manages the timer, and posts alerts when
// test time is winding up.
//
// The timer code relies on the existence of data attributes for the gwTimer div created by GatewayQuiz.pm.

(() => {
	// Gateway timer
	const timerDiv = document.getElementById('gwTimer'); // The timer div element
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
				sessionStorage.removeItem('gatewayAlertStatus');
				document.gwquiz.submitAnswers.click();
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
			if (remainingTime <= 10 - gracePeriod)
				// Submit the test if time is expired and near the end of grace period.
				document.gwquiz.submitAnswers.click();
			else {
				// Set the timer text and check alerts at page load.
				updateTimer();

				// Start the timer.
				setInterval(updateTimer, 1000);
			}
		}
	};

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
