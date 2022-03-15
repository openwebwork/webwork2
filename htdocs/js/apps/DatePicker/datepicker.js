(() => {
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

			flatpickr(rule.parentNode, {
				allowInput: true,
				enableTime: true,
				minuteIncrement: 1,
				altInput: true,
				dateFormat: 'U',
				defaultDate: orig_value,
				defaultHour: 0,
				locale: rule.dataset.locale ? rule.dataset.locale.substring(0, 2) : 'en',
				clickOpens: false,
				disableMobile: true,
				wrap: true,
				plugins: [ new confirmDatePlugin({ confirmText: rule.dataset.doneText ?? 'Done', showAlways: true }) ],
				onChange(selectedDates) {
					// If the altInput field has been emptied, then the formatDate method still sets the hidden input.
					// So set that back to empty again.
					if (!selectedDates.length) this.input.value = '';

					if (this.input.value === orig_value) this.altInput.classList.remove('changed');
					else this.altInput.classList.add('changed');
				},
				onClose: update,
				onReady(selectedDates) {
					// Flatpickr hides the original input and adds the alternate input after it.  That messes up the
					// bootstrap input group styling.  So move the now hidden original input after the created alternate
					// input to fix that.
					this.altInput.after(this.input);

					this.altInput.addEventListener('blur', update);

					// If the inital value is empty, then the formatDate method still sets the hidden input.
					// So set that back to empty again.
					if (!selectedDates.length) this.input.value = '';
				},
				parseDate(datestr, format) {
					// Deal with the case of a unix timestamp on initial load.
					if (format === 'U') return new Date(parseInt(datestr) * 1000);
					// Next attempt to parse the datestr with the current format.
					const date = new Date(Date.parse(datestr, format));
					if (!isNaN(date.getTime())) return date;
					// Finally, fall back to the previous value in the original input if that failed.
					return new Date(parseInt(rule.value) * 1000);
				},
				formatDate(date) {
					// Flatpickr sets the value of the original input to the parsed time.
					// So set that back to the unix timestamp.
					rule.value = date.getTime() / 1000;

					// Return the localized time string.
					return Intl.DateTimeFormat(rule.dataset.locale?.replaceAll(/_/g, '-') ?? 'en',
						{ dateStyle: 'short', timeStyle: 'short', timeZone: rule.dataset.timezone ?? 'UTC' })
						.format(date);
				}
			});
		}
	});
})();
