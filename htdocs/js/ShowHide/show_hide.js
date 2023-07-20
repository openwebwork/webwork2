/* This Javascript attaches the proper event handler to the "Show/Hide Description" button */

(() => {
	const showHide = document.getElementById('show_hide');
	showHide?.addEventListener('click', () => {
		const description = document.getElementById("site_description");
		if (description.style.display === "none") description.style.display = "block";
		else description.style.display = "none";
	});
})();
