(() => {
	// Cause achievement popups to appear and then go away
	document.querySelectorAll('.cheevo-toast').forEach((toast) => {
		const bsToast = new bootstrap.Toast(toast, { delay: 5000 });
		bsToast.show();
	});
})();
