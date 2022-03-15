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
			altInput: true,
			dateFormat: 'U',
			defaultHour: 0,
			locale: importDateShift.dataset.locale ? importDateShift.dataset.locale.substring(0, 2) : 'en',
			clickOpens: false,
			disableMobile: true,
			wrap: true,
			plugins: [ new confirmDatePlugin({ confirmText: importDateShift.dataset.doneText, showAlways: true }) ],
			onReady(selectedDates) {
				// Flatpickr hides the original input and adds the alternate input after it.  That messes up the
				// bootstrap input group styling.  So move the now hidden original input after the created alternate
				// input to fix that.
				this.altInput.after(this.input);

				// If the inital value is empty, then the formatDate method still sets the hidden input.
				// So set that back to empty again.
				if (!selectedDates.length) this.input.value = '';
			},
			onChange(selectedDates) {
				// If the altInput field has been emptied, then the formatDate method still sets the hidden input.
				// So set that back to empty again.
				if (!selectedDates.length) this.input.value = '';
			},
			parseDate(datestr, format) {
				// Deal with the case of a unix timestamp.
				if (format === 'U') return new Date(parseInt(datestr) * 1000);
				// Next attempt to parse the datestr with the current format.
				const date = new Date(Date.parse(datestr, format));
				if (!isNaN(date.getTime())) return date;
				// Finally, fall back to the previous value in the original input if that failed.
				return new Date(parseInt(importDateShift.value) * 1000);
			},
			formatDate(date) {
				// Flatpickr sets the value of the original input to the parsed time.
				// So set that back to the unix timestamp.
				importDateShift.value = date.getTime() / 1000;

				// Return the localized time string.
				return Intl.DateTimeFormat(importDateShift.dataset.locale?.replaceAll(/_/g, '-') ?? 'en',
					{ dateStyle: 'short', timeStyle: 'short', timeZone: importDateShift.dataset.timezone ?? 'UTC' })
					.format(date);
			}
		});
	}
})();
