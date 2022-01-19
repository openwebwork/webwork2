(() => {
	// Show the filter error message if the 'Take Action' button is clicked when matching set IDs without having entered
	// a text to filter on.
	document.getElementById('take_action')?.addEventListener('click',
		(e) => {
			const filter_err_msg = document.getElementById('filter_err_msg');

			if (filter_err_msg &&
				document.getElementById('current_action')?.value === 'filter' &&
				document.getElementById('filter_select')?.selectedIndex === 3 &&
				document.getElementById('filter_text')?.value === '') {
				filter_err_msg.classList.remove('d-none');
				e.preventDefault();
				e.stopPropagation();
			}
		}
	);

	// Toggle the display of the filter elements as the filter select changes.
	const filter_select = document.getElementById('filter_select');
	const filter_elements = document.getElementById('filter_elements');
	const filterElementToggle = () => {
		if (filter_select?.selectedIndex == 3) filter_elements.style.display = 'flex';
		else filter_elements.style.display = 'none';
	};

	if (filter_select) filterElementToggle();
	filter_select?.addEventListener('change', filterElementToggle);
})();
