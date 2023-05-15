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
})();
