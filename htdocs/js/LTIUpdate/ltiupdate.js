(() => {
	// Store select options in dictionary to rebuild the user/set menus from.
	const userOptions = {};
	const setOptions = {};
	const userMenu = document.getElementById('updateUserID');
	const setMenu = document.getElementById('updateSetID');
	for (let i = 1; i < userMenu.length; i++) {
		userOptions[userMenu[i].value] = userMenu[i];
	}
	for (let i = 1; i < setMenu.length; i++) {
		setOptions[setMenu[i].value] = setMenu[i];
	}

	// Update user and set drop down menus to only include valid user/set combinations.
	document.getElementById('updateUserID')?.addEventListener('change', (e) => {
		const setList = e.target.options[e.target.selectedIndex].dataset.sets.split(':');
		const selectedSet = setMenu.value;
		while (setMenu.length > 1) setMenu.lastChild.remove();
		setList.forEach((set) => {
			setMenu.append(setOptions[set]);
		});
		setMenu.value = selectedSet;
	});
	document.getElementById('updateSetID')?.addEventListener('change', (e) => {
		const userList = e.target.options[e.target.selectedIndex].dataset.users.split(':');
		const selectedUser = userMenu.value;
		while (userMenu.length > 1) userMenu.lastChild.remove();
		userList.forEach((user) => {
			userMenu.append(userOptions[user]);
		});
		userMenu.value = selectedUser;
	});
})();
