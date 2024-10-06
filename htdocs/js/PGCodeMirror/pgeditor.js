/* WeBWorK Online Homework Delivery System
 * Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of either: (a) the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any later
 * version, or (b) the "Artistic License" which comes with this package.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
 * Artistic License for more details.
 */

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
