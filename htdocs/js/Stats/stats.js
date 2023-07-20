(() => {
	// Hover action to show exact value of each bar.
	document.querySelectorAll('.bar_graph_bar').forEach((el) => new bootstrap.Tooltip(el, { trigger: 'hover' }));

	if (!webworkConfig.renderProblem) return;

	const displayModeSelector = document.getElementById('problem_displaymode');

	const render = () => {
		webworkConfig.renderProblem('problem_render_area', {
			set_id: document.getElementById('hidden_set_id')?.value,
			probNum: document.getElementById('hidden_problem_id')?.value,
			sourceFilePath: document.getElementById('hidden_source_file')?.value
		});
	};

	// Render the problem on page load.
	render();

	// Re-render when a new display mode is selected.
	displayModeSelector?.addEventListener('change', render);
})();
