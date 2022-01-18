document.querySelectorAll('.action-link').forEach((actionLink) => {
	actionLink.addEventListener('click', () => {
		actionLink.blur();
		document.getElementById("current_action").value = actionLink.dataset.action;
	});
});
