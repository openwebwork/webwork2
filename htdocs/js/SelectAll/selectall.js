// Select all checkbox handling
// Used in UserList.pm, AchievementList.pm, ProblemSetList.pm, and CourseAdmin.pm.

(() => {
	for (const selectAll of document.querySelectorAll('.select-all')) {
		const checks = document.querySelectorAll(`input[name$=${selectAll.dataset.selectGroup}]`);

		if (selectAll.type.toLowerCase() === 'checkbox') {
			// Find additional select alls in the same group if any.
			const pairedSelectAlls =
				document.querySelectorAll(`.select-all[data-select-group="${selectAll.dataset.selectGroup}"]`);

			selectAll.addEventListener('click', () => {
				checks.forEach(check => check.checked = selectAll.checked);

				// Also check/uncheck any select alls in the same group.
				pairedSelectAlls.forEach((check) => check.checked = selectAll.checked);
			});

			checks.forEach(check => check.addEventListener('click',
				() => { if (!check.checked) selectAll.checked = false; }));

			// If all checks in the group are checked when the page loads, then also check the select all check.
			// This can happen in AchievementList.pm.
			selectAll.checked = checks.length && Array.from(checks).every((check) => check.checked);
		}

		if (selectAll.type.toLowerCase() === 'button') {
			selectAll.addEventListener('click', () => checks.forEach(check => check.checked = true));
		}
	}

	for (const selectNone of document.querySelectorAll('.select-none')) {
		const checks = document.querySelectorAll(`input[name$=${selectNone.dataset.selectGroup}]`);
		selectNone.addEventListener('click', () => checks.forEach(check => check.checked = false));
	}
})();
