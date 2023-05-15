(() => {
	const previewUserNameSpan = document.getElementById('preview-user');
	if (previewUserNameSpan) {
		const classListSelect = document.getElementById('classList');
		classListSelect?.addEventListener('change', () => {
			if (classListSelect.selectedIndex !== -1)
				previewUserNameSpan.textContent = classListSelect.options[classListSelect.selectedIndex].textContent;
			else previewUserNameSpan.textContent = previewUserNameSpan.dataset.default;
		});
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
