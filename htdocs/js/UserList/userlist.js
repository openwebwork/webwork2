(() => {
	const filter_select = document.getElementById('filter_select');
	if (filter_select) {
		const classlist_add_filter_elements = () => {
			const filter_elements = document.getElementById('filter_elements');

			if (filter_select.selectedIndex === 3) filter_elements.style.display = 'block';
			else filter_elements.style.display = 'none';
		};

		filter_select.addEventListener('change', classlist_add_filter_elements);
		classlist_add_filter_elements();
	}

	const export_select_target = document.getElementById('export_select_target');
	if (export_select_target) {
		const classlist_add_export_elements = () => {
			const export_elements = document.getElementById('export_elements');
			if (!export_elements) return;

			if (export_select_target.selectedIndex === 0) export_elements.style.display = 'block';
			else export_elements.style.display = 'none';
		};

		export_select_target.addEventListener('change', classlist_add_export_elements);
		classlist_add_export_elements();
	}

	// Submit the user list form when a sort header is clicked or enter or space is pressed when it has focus.
	const userListForm = document.forms['userlist'];
	const currentAction = document.getElementById('current_action');

	if (userListForm && currentAction) {
		for (const header of document.querySelectorAll('.sort-header')) {
			const submitSortMethod = (e) => {
				e.preventDefault();

				currentAction.value = '';

				const sortInput = document.createElement('input');
				sortInput.name = 'labelSortMethod';
				sortInput.value = header.dataset.sortField;
				sortInput.type = 'hidden';
				userListForm.append(sortInput);

				userListForm.submit();
			};

			header.addEventListener('click', submitSortMethod);
			header.addEventListener('keydown', (e) => {
				if (e.key === ' ' || e.key === 'Enter') submitSortMethod(e);
			});
		}
	}
})();
