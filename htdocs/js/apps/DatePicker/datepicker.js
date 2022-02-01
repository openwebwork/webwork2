(() => {
	document.querySelectorAll('.datepicker-group').forEach((open_rule) => {
		if (open_rule.dataset.enableDatepicker !== '1') return;

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
				dateFormat: 'm/d/Y at h:iK',
				clickOpens: false,
				disableMobile: true,
				wrap: true,
				plugins: [ new confirmDatePlugin({ confirmText: rule.dataset.doneText ?? 'Done', showAlways: true }) ],
				onChange() {
					if (rule.value.toLowerCase() !== orig_value) rule.classList.add('changed');
					else rule.classList.remove('changed');
				},
				onClose: update
			});

			rule.addEventListener('blur', update);
		}
	});
})();
