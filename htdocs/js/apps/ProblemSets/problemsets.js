(() => {
	const gwTemplates = document.querySelectorAll('.gw-template');
	gwTemplates.forEach((template) => {
		const quizInfo = template.querySelector('.gwquiz-info');
		const interactive = template.querySelector('a[data-open="1"]');
		if (!quizInfo || !quizInfo.dataset.timeLimit || !interactive) return;

		interactive.addEventListener('click', (e) => {
			e.preventDefault();

			const date = new Date(0);
			date.setSeconds(quizInfo.dataset.timeLimit);
			const timeParts = [];
			const hours = date.getUTCHours();
			if (hours) timeParts.push(`${hours} hour${hours > 1 ? 's' : ''}`);
			const minutes = date.getUTCMinutes();
			if (minutes) timeParts.push(`${minutes} minute${minutes > 1 ? 's' : ''}`);
			const seconds = date.getUTCSeconds();
			if (seconds) timeParts.push(`${seconds}  second${seconds > 1 ? 's' : ''}`);

			const modal = document.createElement('div');
			modal.classList.add('modal');
			modal.tabIndex = -1;
			modal.setAttribute('aria-labelledby', 'gateway-quiz-confirm-start');
			modal.innerHTML = '<div class="modal-dialog modal-dialog-centered"><div class="modal-content">' +
				'<div class="modal-header">' +
				`<h5 class="modal-title" id="gateway-quiz-confirm-start">${
					interactive.dataset.bsTitle || 'Confirm Start of Timed Quiz'}</h5>` +
				'<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="close"></button>' +
				'</div>' +
				'<div class="modal-body">' +
				`<p>${quizInfo.textContent} is a timed quiz.<p>` +
				`<p>You will have ${timeParts.join(" and ")} to complete the quiz.</p>` +
				'<p>Click "Begin" below to start.</p>' +
				'</div>' +
				'<div class="modal-footer">' +
				'<button type="button" class="btn btn-primary" data-bs-dismiss="modal" aria-label="cancel">Cancel' +
				'</button>' +
				'<button id="gw-quiz-confirm-start" type="button" class="btn btn-primary" aria-label="begin">Begin' +
				'</button>' +
				'</div>' +
				'</div></div>';
			document.body.append(modal);

			const bsModal = new bootstrap.Modal(modal);
			const beginQuiz = document.getElementById('gw-quiz-confirm-start');
			beginQuiz.addEventListener('click', () => { bsModal.hide(); window.location = interactive.href; });
			modal.addEventListener('hidden.bs.modal', () => { bsModal.dispose(); modal.remove(); });
			bsModal.show();
		});
	});
})();
