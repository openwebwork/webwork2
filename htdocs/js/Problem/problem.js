(() => {
	// Cause achievement popups to appear and then go away
	document.querySelectorAll('.cheevo-toast').forEach((toast) => {
		const bsToast = new bootstrap.Toast(toast, { delay: 5000 });
		bsToast.show();
	});

	// Prevent problems which are disabled from acting as links
	$('.problem-list .disabled-problem').addClass('disabled').on('click', (e) => e.preventDefault());
})();
