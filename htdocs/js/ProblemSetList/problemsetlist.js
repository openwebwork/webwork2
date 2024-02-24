(() => {
	// Action form validation.
	const show_errors = (ids, elements) => {
		for (const id of ids) elements.push(document.getElementById(id));
		for (const element of elements) {
			if (element?.id.endsWith('_err_msg')) {
				element?.classList.remove('d-none');
			} else {
				element?.classList.add('is-invalid');
				element?.addEventListener('change', hide_errors([], elements));
			}
		}
	};

	const hide_errors = (ids, elements) => {
		return () => {
			for (const id of ids) elements.push(document.getElementById(id));
			for (const element of elements) {
				if (element?.id.endsWith('_err_msg')) {
					element?.classList.add('d-none');
					if (element.id === 'select_set_err_msg')
						document.getElementById('set_table_id')?.removeEventListener('change', hide_errors);
				} else {
					element?.classList.remove('is-invalid');
					element?.removeEventListener('change', hide_errors);
				}
			}
		};
	};

	const is_set_selected = () => {
		for (const set of document.getElementsByName('selected_sets')) {
			if (set.checked) return true;
		}
		const err_msg = document.getElementById('select_set_err_msg');
		err_msg?.classList.remove('d-none');
		document
			.getElementById('set_table_id')
			?.addEventListener(
				'change',
				hide_errors(
					['filter_select', 'edit_select', 'publish_filter_select', 'export_select', 'score_select'],
					[err_msg]
				)
			);
		return false;
	};

	document.getElementById('problemsetlist')?.addEventListener('submit', (e) => {
		const action = document.getElementById('current_action')?.value || '';
		if (action === 'filter') {
			const filter_select = document.getElementById('filter_select');
			const filter = filter_select?.value || '';
			const filter_text = document.getElementById('filter_text');
			if (filter === 'selected' && !is_set_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_set_err_msg'], [filter_select]);
			} else if (filter === 'match_ids' && filter_text.value === '') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['filter_err_msg'], [filter_select, filter_text]);
			}
		} else if (['edit', 'publish', 'export', 'score'].includes(action)) {
			const action_select = document.getElementById(`${action}_select`);
			if (action_select.value === 'selected' && !is_set_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_set_err_msg'], [action_select]);
			}
		} else if (action === 'save_export') {
			if (!is_set_selected()) {
				e.preventDefault();
				e.stopPropagation();
			}
		} else if (action === 'import') {
			const import_select = document.getElementById('import_source_select');
			if (!import_select.value.endsWith('.def')) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['import_file_err_msg'], [import_select]);
			}
		} else if (action === 'create') {
			const create_text = document.getElementById('create_text');
			const create_select = document.getElementById('create_select');
			if (create_text.value === '') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['create_file_err_msg'], [create_text]);
			} else if (create_select?.value == 'copy' && !is_set_selected()) {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['select_set_err_msg'], [create_select]);
			}
		} else if (action === 'delete') {
			const delete_confirm = document.getElementById('delete_select');
			if (!is_set_selected()) {
				e.preventDefault();
				e.stopPropagation();
			} else if (delete_confirm.value != 'yes') {
				e.preventDefault();
				e.stopPropagation();
				show_errors(['delete_confirm_err_msg'], [delete_confirm]);
			}
		}
	});

	// Remove all error messages when changing tabs.
	for (const tab of document.querySelectorAll('a[data-bs-toggle="tab"]')) {
		tab.addEventListener('shown.bs.tab', () => {
			hide_errors(
				[],
				document.getElementById('problemsetlist')?.querySelectorAll('div[id$=_err_msg], .is-invalid')
			)();
		});
	}

	// Toggle the display of the filter elements as the filter select changes.
	const filter_select = document.getElementById('filter_select');
	const filter_elements = document.getElementById('filter_elements');
	const filterElementToggle = () => {
		if (filter_select?.value == 'match_ids') filter_elements.style.display = 'flex';
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

	// Date/time formats for the languages supported by webwork.
	// Note that these formats are chosen to match the perl DateTime::Locale formats.
	// Make sure that anytime a new language is added, its format is added here.
	const datetimeFormats = {
		en: 'L/d/yy, h:mm a',
		'en-US': 'L/d/yy, h:mm a',
		'cs-CZ': 'dd.LL.yy H:mm',
		de: 'dd.LL.yy, HH:mm',
		el: 'd/L/yy, h:mm a',
		es: 'd/L/yy, H:mm',
		'fr-CA': "yyyy-LL-dd HH 'h' mm",
		fr: 'dd/LL/yyyy HH:mm',
		'he-IL': 'd.L.yyyy, H:mm',
		hu: 'yyyy. LL. dd. H:mm',
		ko: 'yy. L. d. a h:mm',
		'ru-RU': 'dd.LL.yyyy, HH:mm',
		tr: 'd.LL.yyyy HH:mm',
		'zh-CN': 'yyyy/L/d ah:mm',
		'zh-HK': 'yyyy/L/d ah:mm'
	};

	// Initialize the date/time picker for the import form.
	const importDateShift = document.getElementById('import_date_shift');
	if (importDateShift) {
		luxon.Settings.defaultLocale = importDateShift.dataset.locale ?? 'en';

		// Compute the time difference between the current browser timezone and the course timezone.
		// flatpickr gives the time in the browser's timezone, and this is used to adjust to the course timezone.
		// Note that this is in seconds.
		const timezoneAdjustment =
			new Date(new Date().toLocaleString('en-US')).getTime() -
			new Date(
				new Date().toLocaleString('en-US', { timeZone: importDateShift.dataset.timezone ?? 'America/New_York' })
			).getTime();

		const fp = flatpickr(importDateShift.parentNode, {
			allowInput: true,
			enableTime: true,
			minuteIncrement: 1,
			altInput: true,
			dateFormat: 'U',
			altFormat: datetimeFormats[luxon.Settings.defaultLocale],
			ariaDateFormat: datetimeFormats[luxon.Settings.defaultLocale],
			defaultHour: 0,
			locale:
				luxon.Settings.defaultLocale.substring(0, 2) === 'el'
					? 'gr'
					: luxon.Settings.defaultLocale.substring(0, 2),
			clickOpens: false,
			disableMobile: true,
			wrap: true,
			plugins: [
				new confirmDatePlugin({ confirmText: importDateShift.dataset.doneText, showAlways: true }),
				new ShortcutButtonsPlugin({
					button: [
						{
							label: importDateShift.dataset.todayText ?? 'Today',
							attributes: { class: 'btn btn-sm btn-secondary ms-auto me-1 mb-1' }
						},
						{
							label: importDateShift.dataset.nowText ?? 'Now',
							attributes: { class: 'btn btn-sm btn-secondary mx-auto mb-1' }
						}
					],
					onClick: (index, fp) => {
						if (index === 0) {
							const today = new Date();
							// If there isn't a selected date, then use 12:00 am on the current date.
							const selectedDate = fp.selectedDates[0] ?? new Date(new Date().toDateString());
							selectedDate.setFullYear(today.getFullYear());
							selectedDate.setMonth(today.getMonth());
							selectedDate.setDate(today.getDate());
							fp.setDate(selectedDate);
						} else if (index === 1) {
							fp.setDate(new Date());
						}
					}
				})
			],
			onReady(selectedDates) {
				// Flatpickr hides the original input and adds the alternate input after it.  That messes up the
				// bootstrap input group styling.  So move the now hidden original input after the created alternate
				// input to fix that.
				this.altInput.after(this.input);

				// Make the alternate input left-to-right even for right-to-left languages.
				this.altInput.dir = 'ltr';
			},
			parseDate(datestr, format) {
				// Deal with the case of a unix timestamp.  The timezone needs to be adjusted back as this is for
				// the unix timestamp stored in the hidden input whose value will be sent to the server.
				if (format === 'U') return new Date(parseInt(datestr) * 1000 - timezoneAdjustment);

				// Next attempt to parse the datestr with the current format.  This should not be adjusted.  It is
				// for display only.
				const date = luxon.DateTime.fromFormat(datestr.replaceAll(/\u202F/g, ' ').trim(), format);
				if (date.isValid) return date.toJSDate();

				// Finally, fall back to the previous value in the original input if that failed.  This is the case
				// that the user typed a time that isn't in the valid format. So fallback to the last valid time
				// that was displayed. This also should not be adjusted.
				return new Date(this.lastFormattedDate.getTime());
			},
			formatDate(date, format) {
				// Save this date for the fallback in parseDate.
				this.lastFormattedDate = date;

				// In this case the date provided is in the browser's time zone.  So it needs to be adjusted to the
				// timezone of the course.
				if (format === 'U') return (date.getTime() + timezoneAdjustment) / 1000;

				return luxon.DateTime.fromMillis(date.getTime()).toFormat(
					datetimeFormats[luxon.Settings.defaultLocale]
				);
			}
		});

		importDateShift.nextElementSibling.addEventListener('keydown', (e) => {
			if (e.key === ' ' || e.key === 'Enter') {
				e.preventDefault();
				fp.open();
			}
		});
	}
})();
