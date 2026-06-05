(() => {
	const addOnConfSelect = document.getElementById('add_on_conf');
	const addOnConfOptgroups = [...addOnConfSelect.querySelectorAll('optgroup')];

	// Track previously selected options to identify the newly clicked option
	let previousSelection = [];

	addOnConfSelect.addEventListener('change', (event) => {
		const currentSelection = Array.from(addOnConfSelect.selectedOptions);

		// Find the option the user just clicked/selected
		const newlySelected = currentSelection.find((option) => !previousSelection.includes(option));

		if (newlySelected) {
			// Find the parent optgroup
			const parent = newlySelected.closest('optgroup');

			// Loop through all options in the other groups and unselect them as appropriate
			addOnConfOptgroups.forEach((group) => {
				Array.from(group.children).forEach((option) => {
					if (
						option !== newlySelected &&
						(parent.dataset.single || (!parent.dataset.single && group.dataset.single))
					) {
						option.selected = false;
					}
				});
			});
		}

		// Update tracking variable for the next change event
		previousSelection = Array.from(addOnConfSelect.selectedOptions);
	});
})();
