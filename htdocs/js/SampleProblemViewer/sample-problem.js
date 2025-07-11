for (const pre of document.body.querySelectorAll('pre.PGCodeMirror')) {
	PGCodeMirrorEditor.runMode(pre.textContent, pre);
}

for (const btn of document.querySelectorAll('.clipboard-btn')) {
	if (navigator.clipboard) btn.addEventListener('click', () => navigator.clipboard.writeText(btn.dataset.code));
}
