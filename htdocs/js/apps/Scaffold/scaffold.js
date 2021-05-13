window.addEventListener('DOMContentLoaded', function() {
	var sections = $('.section-div .collapse');
	sections.on('show', function() {
		this.style.display = 'block';

		// Reflow MathQuill answer boxes contained in the section so that their contents are rendered correctly.
		var section = this;
		if (window.answerQuills) {
			Object.keys(answerQuills).forEach(
				function(quill) { if (section.querySelector('#' + quill)) answerQuills[quill].mathField.reflow(); }
			);
		}
	});

	// Hide the accordion content while collapsed to remove its contents from the tab order.
	sections.on('hidden', function() { this.style.display = 'none'; });
});
