(() => {
	// Date/time formats for the languages supported by webwork.
	// Note that these formats are chosen to match the perl DateTime::Locale formats.
	// Make sure that anytime a new language is added, its format is added here.
	const datetimeFormats = {
		en: 'L/d/yy, h:mm a',
		'en-US': 'L/d/yy, h:mm a',
		'en-GB': 'dd/LL/yyyy, HH:mm',
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

	document.querySelectorAll('.datepicker-group').forEach((open_rule) => {
		const name = open_rule.name.replace('.open_date', '');

		const groupRules = [
			[open_rule],
			[document.getElementById(`${name}.due_date_id`)],
			[document.getElementById(`${name}.answer_date_id`)]
		];

		const reduced_rule = document.getElementById(`${name}.reduced_scoring_date_id`);
		if (reduced_rule) groupRules.splice(1, 0, [reduced_rule]);

		// Compute the time difference between the current browser timezone and the course timezone.
		// flatpickr gives the time in the browser's timezone, and this is used to adjust to the course timezone.
		// Note that this is in seconds.
		const timezoneAdjustment =
			new Date(new Date().toLocaleString('en-US')).getTime() -
			new Date(
				new Date().toLocaleString('en-US', { timeZone: open_rule.dataset.timezone ?? 'America/New_York' })
			).getTime();

		for (const rule of groupRules) {
			const value =
				rule[0].value || document.getElementsByName(`${rule[0].name}.class_value`)[0]?.dataset.classValue;
			rule.push(value ? parseInt(value) * 1000 - timezoneAdjustment : 0);
		}

		const update = (input) => {
			const activeIndex = groupRules.findIndex((r) => r[0] === input);
			if (activeIndex == -1) return;
			const activeFieldDate =
				groupRules[activeIndex][0]?.parentNode._flatpickr.selectedDates[0]?.getTime() ||
				groupRules[activeIndex][1];

			for (let i = 0; i < groupRules.length; ++i) {
				if (i == activeFieldDate) continue;
				const thisFieldDate =
					groupRules[i][0]?.parentNode._flatpickr.selectedDates[0]?.getTime() || groupRules[i][1];
				if (i < activeIndex && thisFieldDate > activeFieldDate)
					groupRules[i][0].parentNode._flatpickr.setDate(activeFieldDate, true);
				else if (i > activeIndex && thisFieldDate < activeFieldDate)
					groupRules[i][0].parentNode._flatpickr.setDate(activeFieldDate, true);
			}
		};

		for (const rule of groupRules) {
			const orig_value = rule[0].value;
			let fallbackDate = rule[1] ? new Date(rule[1]) : new Date();

			luxon.Settings.defaultLocale = rule[0].dataset.locale ?? 'en';

			const fp = flatpickr(rule[0].parentNode, {
				allowInput: true,
				enableTime: true,
				minuteIncrement: 1,
				altInput: true,
				dateFormat: 'U',
				altFormat: datetimeFormats[luxon.Settings.defaultLocale],
				ariaDateFormat: datetimeFormats[luxon.Settings.defaultLocale],
				defaultDate: orig_value,
				defaultHour: 0,
				locale:
					luxon.Settings.defaultLocale.substring(0, 2) === 'el'
						? 'gr'
						: luxon.Settings.defaultLocale.substring(0, 2),
				clickOpens: false,
				disableMobile: true,
				wrap: true,
				plugins: [
					new confirmDatePlugin({ confirmText: rule[0].dataset.doneText ?? 'Done', showAlways: true }),
					new ShortcutButtonsPlugin({
						button: [
							{
								label: rule[0].dataset.todayText ?? 'Today',
								attributes: { class: 'btn btn-sm btn-secondary ms-auto me-1 mb-1' }
							},
							{
								label: rule[0].dataset.nowText ?? 'Now',
								attributes: { class: 'btn btn-sm btn-secondary me-auto mb-1' }
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
				onChange() {
					if (this.input.value === orig_value) this.altInput.classList.remove('changed');
					else this.altInput.classList.add('changed');
				},
				onClose() {
					return update(this.input);
				},
				onReady() {
					// Flatpickr hides the original input and adds the alternate input after it.  That messes up the
					// bootstrap input group styling.  So move the now hidden original input after the created alternate
					// input to fix that.
					this.altInput.after(this.input);

					// Move the id of the now hidden input onto the added input so the labels still work.
					this.altInput.id = this.input.id;

					// Remove the placeholder from the hidden input.  Flatpickr has copied that to the added input, and
					// that isn't valid on a hidden input.
					this.input.removeAttribute('id');
					this.input.removeAttribute('placeholder');

					// Make the alternate input left-to-right even for right-to-left languages.
					this.altInput.dir = 'ltr';

					this.altInput.addEventListener('blur', () => update(this.input));
				},
				parseDate(datestr, format) {
					// Deal with the case of a unix timestamp.  The timezone needs to be adjusted back as this is for
					// the unix timestamp stored in the hidden input whose value will be sent to the server.
					if (format === 'U') return new Date(parseInt(datestr) * 1000 - timezoneAdjustment);

					// Next attempt to parse the datestr with the current format.  This should not be adjusted.  It is
					// for display only.
					const date = luxon.DateTime.fromFormat(datestr.replaceAll(/\u202F/g, ' ').trim(), format);
					if (date.isValid) fallbackDate = date.toJSDate();

					// Finally, fall back to the previous value in the original input if that failed.  This is the case
					// that the user typed a time that isn't in the valid format. So fallback to the last valid time
					// that was displayed. This also should not be adjusted.
					return fallbackDate;
				},
				formatDate(date, format) {
					// In this case the date provided is in the browser's time zone.  So it needs to be adjusted to the
					// timezone of the course.
					if (format === 'U') return (date.getTime() + timezoneAdjustment) / 1000;

					return luxon.DateTime.fromMillis(date.getTime()).toFormat(
						datetimeFormats[luxon.Settings.defaultLocale]
					);
				}
			});

			rule[0].nextElementSibling.addEventListener('keydown', (e) => {
				if (e.key === ' ' || e.key === 'Enter') {
					e.preventDefault();
					fp.open();
				}
			});
		}
	});
})();
