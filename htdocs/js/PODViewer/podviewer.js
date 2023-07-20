(() => {
	const offcanvas = bootstrap.Offcanvas.getOrCreateInstance(document.getElementById('sidebar'));
	for (const link of document.querySelectorAll('#sidebar .nav-link')) {
		// The timeout is to workaround an issue in Chrome. If the offcanvas hides before the window scrolls to the
		// fragment in the page, scrolling stops before it gets there.
		link.addEventListener('click', () => setTimeout(() => offcanvas.hide(), 500));
	}
})();
