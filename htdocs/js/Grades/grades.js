(() => {
	const toggleWeightsButton = document.getElementById('toggle-weights');
	const toggleAttemptsButton = document.getElementById('toggle-attempts');
	const courseID = document.getElementsByName('hidden_course_id')[0]?.value ?? 'unknownCourse';
	const showHideRows = (button) => {
		if (button.dataset.hidden === '1') {
			document.querySelectorAll('.' + button.dataset.rowClass).forEach((e) => {
				e.classList.remove('d-none');
			});
			button.dataset.hidden = '0';
			button.textContent = button.dataset.hideText;
			localStorage.setItem(`WW.${courseID}.grades.show-${button.dataset.rowClass}`, true);
		} else {
			document.querySelectorAll('.' + button.dataset.rowClass).forEach((e) => {
				e.classList.add('d-none');
			});
			button.dataset.hidden = '1';
			button.textContent = button.dataset.showText;
			localStorage.removeItem(`WW.${courseID}.grades.show-${button.dataset.rowClass}`);
		}
	};

	toggleWeightsButton?.addEventListener('click', () => showHideRows(toggleWeightsButton));
	toggleAttemptsButton?.addEventListener('click', () => showHideRows(toggleAttemptsButton));

	document.addEventListener('DOMContentLoaded', () => {
		for (const button of [toggleWeightsButton, toggleAttemptsButton]) {
			if (button && localStorage.getItem(`WW.${courseID}.grades.show-${button.dataset.rowClass}`))
				showHideRows(button);
		}
	});
})();
