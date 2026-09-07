(() => {
	window.parent.postMessage('render-iframe-ready');
	window.addEventListener('message', (event) => {
		if (!event.data || !event.data.theme) return;
		document.documentElement.dataset.bsTheme = event.data.theme;
	});
})();
