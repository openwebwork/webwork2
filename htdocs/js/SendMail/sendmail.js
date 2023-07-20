(() => {
	const previewUserNameSpan = document.getElementById('preview-user');
	const classListSelect = document.getElementById('classList');
	if (previewUserNameSpan && classListSelect) {
		const setPreviewUser = () => {
			if (classListSelect.selectedIndex !== -1)
				previewUserNameSpan.textContent = classListSelect.options[classListSelect.selectedIndex].textContent;
			else previewUserNameSpan.textContent = previewUserNameSpan.dataset.default;
		};
		classListSelect.addEventListener('change', setPreviewUser);

		// The timeout should not be needed.  For some reason the classList select is not set correctly on Google
		// Chrome when the page first loads after the back button is pressed, and it takes a bit for it to be set.
		setTimeout(setPreviewUser, 100);
	}

	for (const select of [
		['openfilename', 'openMessage'],
		['merge_file', 'viewMergeFile']
	]) {
		document.getElementById(select[0])?.addEventListener('change', () => {
			const mailForm = document.forms['mail-main-form'];
			if (!mailForm) return;
			const submit = document.createElement('input');
			submit.type = 'submit';
			submit.name = select[1];
			submit.style.display = 'none';
			mailForm.append(submit);
			submit.click();
		});
	}
})();
