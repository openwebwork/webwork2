(() => {
	const takeAction = document.getElementById('take_action');
	const currentAction = document.getElementById('current_action');

	document.querySelectorAll('.action-link').forEach((actionLink) => {
		actionLink.addEventListener('show.bs.tab', () => {
			if (takeAction) takeAction.value = actionLink.textContent;
			if (currentAction) currentAction.value = actionLink.dataset.action;
		});
	});

	// Submit the form when a sort header is clicked or enter or space is pressed when it has focus.
	if (currentAction) {
		for (const header of document.querySelectorAll('.sort-header')) {
			const submitSortMethod = (e) => {
				e.preventDefault();

				currentAction.value = 'sort';

				const sortInput = document.createElement('input');
				sortInput.name = 'labelSortMethod';
				sortInput.value = header.dataset.sortField;
				sortInput.type = 'hidden';
				currentAction.form.append(sortInput);

				currentAction.form.submit();
			};

			header.addEventListener('click', submitSortMethod);
			header.addEventListener('keydown', (e) => {
				if (e.key === ' ' || e.key === 'Enter') submitSortMethod(e);
			});
		}
	}
})();
