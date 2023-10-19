(() => {
	// Show/hide the filter elements depending on if the field matching option is selected.
	const filter_select = document.getElementById('filter_select');
	const filter_elements = document.getElementById('filter_elements');
	if (filter_select && filter_elements) {
		const toggle_filter_elements = () => {
			if (filter_select.value === 'match_regex') filter_elements.style.display = 'block';
			else filter_elements.style.display = 'none';
		};
		filter_select.addEventListener('change', toggle_filter_elements);
		toggle_filter_elements();
	}

	const export_select_target = document.getElementById('export_select_target');
	if (export_select_target) {
		const classlist_add_export_elements = () => {
			const export_elements = document.getElementById('export_elements');
			if (!export_elements) return;

			if (export_select_target.selectedIndex === 0) export_elements.style.display = 'block';
			else export_elements.style.display = 'none';
		};

		export_select_target.addEventListener('change', classlist_add_export_elements);
		classlist_add_export_elements();
	}
})();
