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

	// This will make the popup menu alternate between a single selection and a multiple selection menu.
	const importAmtSelect = document.getElementById('import_amt_select');
	if (importAmtSelect) {
		importAmtSelect.addEventListener('change', () => {
			const numSelect = document.problemsetlist['action.import.number'];
			const number = parseInt(numSelect.options[numSelect.selectedIndex].value);
			document.problemsetlist['action.import.source'].size = number;
			document.problemsetlist['action.import.source'].multiple = number > 1 ? true : false;
			document.problemsetlist['action.import.name'].value = number > 1 ? '(taken from filenames)' : '';
			document.problemsetlist['action.import.name'].readOnly = number > 1 ? true : false;
			document.problemsetlist['action.import.name'].disabled = number > 1 ? true : false;
		});
	}

	// Initialize the date/time picker for the import form.
	const importDateShift = document.getElementById('import_date_shift');
	if (importDateShift) {
		flatpickr(importDateShift.parentNode, {
			allowInput: true,
			enableTime: true,
			minuteIncrement: 1,
			dateFormat: 'm/d/Y at h:iK',
			clickOpens: false,
			disableMobile: true,
			wrap: true,
			plugins: [
				new confirmDatePlugin({
					confirmText: importDateShift.dataset.doneText,
					showAlways: true, theme: 'dark'
				})
			],
		});
	}
})();
