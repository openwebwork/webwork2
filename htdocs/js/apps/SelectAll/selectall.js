// Select all checkbox handling
// Used in UserList.pm, AchievementList.pm, and ProblemSetList.pm.

(() => {
	const selectAll = document.getElementById('select-all');
	if (selectAll) {
		const checks = document.querySelectorAll(`input[name=${selectAll.dataset.selectGroup}]`);
		selectAll.addEventListener('click', () => checks.forEach(check => check.checked = selectAll.checked));
		checks.forEach(check => check.addEventListener('click',
			() => { if (!check.checked) selectAll.checked = false }));
	}
})();
