(() => {
	// Hover action to show exact value of each bar.
	document.querySelectorAll('.bar_graph_bar').forEach((el) => {
		el.addEventListener('mousemove', (evt) => {
			const tooltip = document.getElementById('bar_tooltip');
			tooltip.innerHTML = evt.target.dataset.tooltip;
			tooltip.style.display = 'block';
			tooltip.style.left = evt.pageX + 10 + 'px';
			tooltip.style.top = evt.pageY + 10 + 'px';
		});
		el.addEventListener('mouseout', () => {
			document.getElementById('bar_tooltip').style.display = 'none';
		});
	});
})();
