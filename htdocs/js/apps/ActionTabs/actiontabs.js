(() => {
	const takeAction = document.getElementById('take_action');

	document.querySelectorAll('.action-link').forEach((actionLink) => {
		const currentAction = document.getElementById('current_action');
		actionLink.addEventListener('show.bs.tab', () => {
			if (takeAction) takeAction.value = actionLink.textContent;
			if (currentAction) currentAction.value = actionLink.dataset.action;
		});
	});
})();
