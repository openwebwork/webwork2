(async () => {
	const editorContainer = document.querySelector('.code-mirror-editor');
	if (!PGCodeMirrorEditor || !editorContainer) return;

	const editorInput = document.getElementsByName(editorContainer.id)[0];

	const cm = (webworkConfig.pgCodeMirror = new PGCodeMirrorEditor.View(editorContainer, {
		source: editorInput?.value ?? '',
		language: editorContainer.dataset.language ?? 'pg'
	}));

	new ResizeObserver(() => cm.refresh('window-resize')).observe(editorContainer);

	editorInput?.form.addEventListener('submit', () => (editorInput.value = cm.source));
})();
