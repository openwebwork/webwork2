(function() {
	// Set up popovers in the attemptResults table.
	if ($.fn.popover) { $("table.attemptResults td span.answer-preview").popover({ trigger: 'click' }); }
})();
