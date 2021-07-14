(function() {
	var gwTemplates = document.querySelectorAll('.gw-template');
	gwTemplates.forEach(function(template) {
		var quizInfo = template.querySelector('.gwquiz-info');
		var interactive = template.querySelector('a[data-open="1"]');
		if (!quizInfo || !quizInfo.dataset.timeLimit || !interactive) return;

		interactive.addEventListener('click', function(e) {
			e.preventDefault();

			var date = new Date(0);
			date.setSeconds(quizInfo.dataset.timeLimit);
			let timeParts = [];
			var hours = date.getUTCHours();
			if (hours) timeParts.push(hours + " hour" + (hours > 1 ? "s" : ""));
			var minutes = date.getUTCMinutes();
			if (minutes) timeParts.push(minutes + " minute" + (minutes > 1 ? "s" : ""));
			var seconds = date.getUTCSeconds();
			if (seconds) timeParts.push(seconds + " second" + (seconds > 1 ? "s" : ""));

			var modal = document.createElement('div');
			modal.classList.add('modal');
			modal.tabIndex = -1;
			modal.role = "dialog";
			modal.ariaLabel = "gateway quiz confirm start";
			modal.innerHTML = '<div class="modal-header">' +
				'<button type="button" class="close" data-dismiss="modal" aria-label="close">' +
				'<span aria-hidden="true">&times;</span>' +
				'</button>' +
				'<h3>' + (interactive.dataset.originalTitle || 'Confirm Start of Timed Quiz') + '</h3>' +
				'</div>' +
				'<div class="modal-body">' +
				'<p>' + quizInfo.textContent + ' is a timed quiz.<p>' +
				'<p>You will have ' + timeParts.join(" and ") + ' to complete the quiz.</p>' +
				'<p>Click "Begin" below to start.</p>' +
				'</div>' +
				'<div class="modal-footer">' +
				'<button type="button" class="btn btn-primary" data-dismiss="modal" aria-label="cancel">Cancel</a>' +
				'<button id="gw-quiz-confirm-start" type="button" class="btn btn-primary" aria-label="begin">Begin</a>' +
				'</div>' +
				'</div>';
			document.body.append(modal);

			var jqModal = $(modal);
			var beginQuiz = document.getElementById('gw-quiz-confirm-start');
			beginQuiz.addEventListener('click', function() { jqModal.modal('hide'); window.location = interactive.href; });
			jqModal.on('hidden', function() { modal.remove(); })
			jqModal.modal('show');
		});
	});
})();
