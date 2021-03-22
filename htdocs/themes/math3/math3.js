(function() {
	// Set up popovers in the attemptResults table.
	if ($.fn.popover) { $("table.attemptResults td span.answer-preview").popover({ trigger: 'click' }); }

	// Turn help boxes into popovers
	if ($.fn.popover) {
		$('a.help-popup').popover({trigger : 'hover'}).click(function (e) { e.preventDefault(); });
	}
})();
