(() => {
	// Show/hide the filter elements depending on if the field matching option is selected.
	const filter_select = document.getElementById('filter_select');
	const filter_elements = document.getElementById('filter_elements');
	if (filter_select && filter_elements) {
		const toggle_filter_elements = () => {
			if (filter_select.value === 'match_regex') filter_elements.style.display = 'block';
			else filter_elements.style.display = 'none';
		};
		filter_select.addEventListener('change', toggle_filter_elements);
		toggle_filter_elements();
	}

	// Submit the job list form when a sort header is clicked or enter or space is pressed when it has focus.
	const currentAction = document.getElementById('current_action');
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

	// Activate the results popovers.
	document.querySelectorAll('.result-popover-btn').forEach((popoverBtn) => {
		new bootstrap.Popover(popoverBtn, {
			trigger: 'hover focus',
			customClass: 'job-queue-result-popover',
			html: true
		});
	});
})();
