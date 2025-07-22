(() => {
	// Save user menus to be updated.
	const sourceSingleUserMenu = document.getElementById('sourceSingleUserID');
	const destSingleUserMenu = document.getElementById('destSingleUserID');
	const sourceMultipleUserMenu = document.getElementById('sourceMultipleUserID');
	const destResetUserMenu = document.getElementById('destResetUserID');

	const updateUserMenu = (e, menu, selectFirst) => {
		const userList = e.target.options[e.target.selectedIndex].dataset.users.split(':');
		while (menu.length > 1) menu.lastChild.remove();
		if (selectFirst) {
			menu.selectedIndex = 0;
		}
		userList.forEach((user) => {
			const userOption = document.createElement('option');
			userOption.value = userOption.text = user;
			menu.append(userOption);
		});
	};

	// Update user menu when course ID is selected/changed.
	document.getElementById('sourceSingleCourseID')?.addEventListener('change', (e) => {
		updateUserMenu(e, sourceSingleUserMenu, true);
	});
	document.getElementById('destSingleCourseID')?.addEventListener('change', (e) => {
		updateUserMenu(e, destSingleUserMenu, true);
	});
	document.getElementById('sourceMultipleCourseID')?.addEventListener('change', (e) => {
		updateUserMenu(e, sourceMultipleUserMenu, false);
	});
	document.getElementById('sourceResetCourseID')?.addEventListener('change', (e) => {
		updateUserMenu(e, destResetUserMenu, false);
	});
})();
