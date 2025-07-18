(() => {
	// Store select options in dictionary to rebuild the set select from.
	const setOptions = {};
	const userMenu = document.getElementById('updateUserID');
	const setMenu = document.getElementById('updateSetID');
	const setSelectAll = document.getElementById('selectAllSets');
	for (const option of setMenu.options) {
		setOptions[option.value] = option;
	}

	// Update set select to only include valid sets for the current selected user.
	const updateSetMenu = () => {
		const setList = userMenu.options[userMenu.selectedIndex].dataset.sets.split(':');
		const selectedSets = {};
		let allSelected = true;
		for (const option of setMenu.options) {
			if (option.selected) selectedSets[option.value] = true;
		}
		while (setMenu.length > 0) setMenu.lastChild.remove();
		setList.forEach((set) => {
			setMenu.append(setOptions[set]);
			const option = setMenu.lastChild;
			if (option.value in selectedSets) {
				option.selected = true;
			} else {
				option.selected = false;
				allSelected = false;
			}
		});
		setSelectAll.checked = allSelected;
	};

	// Deal with the select all sets checkbox to either select all sets or uncheck if a set is unselected.
	userMenu?.addEventListener('change', updateSetMenu);
	setMenu?.addEventListener('change', (e) => {
		let allSelected = true;
		for (const option of setMenu.options) {
			if (!option.selected) allSelected = false;
		}
		setSelectAll.checked = allSelected;
	});
	setSelectAll?.addEventListener('change', () => {
		for (const option of setMenu.options) {
			option.selected = setSelectAll.checked;
		}
	});

	// Update the set list on page load.
	window.addEventListener('load', () => {
		if (userMenu.value !== '') updateSetMenu();
	});
})();
