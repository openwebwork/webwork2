(() => {
	// Date/time formats for the languages supported by webwork.
	// Note that these formats are chosen to match the perl DateTime::Locale formats.
	// Make sure that anytime a new language is added, its format is added here.
	const datetimeFormats = {
		en: 'L/d/yy, h:mm a',
		'en-US': 'L/d/yy, h:mm a',
		'cs-CZ': 'dd.LL.yy H:mm',
		de: 'dd.LL.yy, HH:mm',
		es: 'd/L/yy H:mm',
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

	document.querySelectorAll('.datepicker-group').forEach((open_rule) => {
		const name = open_rule.name.replace('.open_date', '');

		const groupRules = [
			open_rule,
			document.querySelector('input[id="' + name + '.due_date_id"]'),
			document.querySelector('input[id="' + name + '.answer_date_id"]')
		];

		const reduced_rule = document.querySelector('input[id="' + name + '.reduced_scoring_date_id"]');
		if (reduced_rule) groupRules.splice(1, 0, reduced_rule);

		const update = () => {
			for (let i = 1; i < groupRules.length; ++i) {
				const prevFieldDate = groupRules[i - 1].parentNode._flatpickr.selectedDates[0];
				const thisFieldDate = groupRules[i].parentNode._flatpickr.selectedDates[0];
				if (prevFieldDate && thisFieldDate && prevFieldDate > thisFieldDate) {
					groupRules[i].parentNode._flatpickr.setDate(prevFieldDate, true);
				}
			}
		};

		for (const rule of groupRules) {
			const orig_value = rule.value;

			luxon.Settings.defaultLocale = rule.dataset.locale ?? 'en';

			// Compute the time difference between the current browser timezone and the course timezone.
			// flatpickr gives the time in the browser's timezone, and this is used to adjust to the course timezone.
			// Note that this is in seconds.
			const timezoneAdjustment = (
				(new Date((new Date).toLocaleString('en-US'))).getTime() -
				(new Date((new Date).toLocaleString('en-US',
					{ timeZone: rule.dataset.timezone ?? 'America/New_York' }))).getTime()
			);

			const fp = flatpickr(rule.parentNode, {
				allowInput: true,
				enableTime: true,
				minuteIncrement: 1,
				altInput: true,
				dateFormat: 'U',
				altFormat: datetimeFormats[luxon.Settings.defaultLocale],
				ariaDateFormat: datetimeFormats[luxon.Settings.defaultLocale],
				defaultDate: orig_value,
				defaultHour: 0,
				locale: rule.dataset.locale ? rule.dataset.locale.substring(0, 2) : 'en',
				clickOpens: false,
				disableMobile: true,
				wrap: true,
				plugins: [
					new confirmDatePlugin({ confirmText: rule.dataset.doneText ?? 'Done', showAlways: true }),
					new ShortcutButtonsPlugin({
						button: [
							{
								label: rule.dataset.todayText ?? 'Today',
								attributes: { class: 'btn btn-sm btn-secondary ms-auto me-1 mb-1' }
							},
							{
								label: rule.dataset.nowText ?? 'Now',
								attributes: { class: 'btn btn-sm btn-secondary me-auto mb-1' }
							}
						],
						onClick: (index, fp) => {
							if (index === 0) {
								const today = new Date();
								// If there isn't a selected date, then use 12:00 am on the current date.
								const selectedDate = fp.selectedDates[0] ?? new Date(new Date().toDateString());
								selectedDate.setFullYear(today.getFullYear())
								selectedDate.setMonth(today.getMonth())
								selectedDate.setDate(today.getDate());
								fp.setDate(selectedDate);
							} else if (index === 1) {
								fp.setDate(new Date());
							}
						}
					})
				],
				onChange(selectedDates) {
					if (this.input.value === orig_value) this.altInput.classList.remove('changed');
					else this.altInput.classList.add('changed');
				},
				onClose: update,
				onReady(selectedDates) {
					// Flatpickr hides the original input and adds the alternate input after it.  That messes up the
					// bootstrap input group styling.  So move the now hidden original input after the created alternate
					// input to fix that.
					this.altInput.after(this.input);

					// Make the alternate input left-to-right even for right-to-left languages.
					this.altInput.dir = 'ltr';

					this.altInput.addEventListener('blur', update);
				},
				parseDate(datestr, format) {
					// Deal with the case of a unix timestamp.  The timezone needs to be adjusted back as this is for
					// the unix timestamp stored in the hidden input whose value will be sent to the server.
					if (format === 'U') return new Date(parseInt(datestr) * 1000 - timezoneAdjustment);

					// Next attempt to parse the datestr with the current format.  This should not be adjusted.  It is
					// for display only.
					const date = luxon.DateTime.fromFormat(datestr, format);
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

					return luxon.DateTime.fromMillis(date.getTime())
						.toFormat(datetimeFormats[luxon.Settings.defaultLocale]);
				}
			});

			rule.nextElementSibling.addEventListener('keydown', (e) => {
				if (e.key === ' ' || e.key === 'Enter') {
					e.preventDefault();
					fp.open();
				}
			});
		}
	});
})();
