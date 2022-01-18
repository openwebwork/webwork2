(() => {
	const attachListeners = (node) => {
		node.querySelectorAll('.collapse').forEach((section) => {
			section.addEventListener('shown.bs.collapse', () => {
				// Reflow MathQuill answer boxes so that their contents are rendered correctly
				if (window.answerQuills) {
					Object.keys(answerQuills).forEach(
						(quill) => { if (section.querySelector('#' + quill)) answerQuills[quill].mathField.reflow(); }
					);
				}
			});
		})
	};

	// Set up any scaffolds already on the page.
	document.querySelectorAll('.section-div').forEach(attachListeners);

	// Observer that sets up scaffolds.
	const observer = new MutationObserver((mutationsList) => {
		mutationsList.forEach((mutation) => {
			mutation.addedNodes.forEach((node) => {
				if (node instanceof Element) {
					if (node.classList.contains('section-div')) attachListeners(node);
					else node.querySelectorAll('.section-div').forEach(attachListeners);
				}
			});
		});
	});
	observer.observe(document.body, { childList: true, subtree: true });

	// Stop the mutation observer when the window is closed.
	window.addEventListener('unload', () => observer.disconnect());
})();
