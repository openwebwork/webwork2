(() => {
	// Format names are templates in which each field name is replaced by that field's display value.
	const formats = {
		user: [
			['lnfn_email', 'last_name, first_name (email_address)'],
			['lnfn_recitation', 'last_name, first_name (recitation)'],
			['lnfn_section', 'last_name, first_name (section)'],
			['lnfn_secrec', 'last_name, first_name (section/recitation)'],
			['lnfn_uid', 'last_name, first_name (user_id)'],
			['uid_lnfn', 'user_id - last_name, first_name']
		],
		set: [
			['type_sid_due', 'assignment_type: set_id, due_date'],
			['due_sid', 'due_date: set_id'],
			['sid', 'set_id']
		]
	};

	const sorts = {
		user: [
			['user_id', 'user_id', ['user_id']],
			['first_name', 'first_name', ['first_name']],
			['last_name', 'last_name', ['last_name']],
			['email_address', 'email_address', ['email_address']],
			['section', 'section', ['section']],
			['recitation', 'recitation', ['recitation']],
			['lnfn', 'last_name, first_name', ['last_name', 'first_name']]
		],
		set: [
			['set_id', 'set_id', ['set_id']],
			['due_date', 'due_date', ['due_date']],
			['assignment_type', 'assignment_type', ['assignment_type']]
		]
	};

	const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });

	const fillSelect = (select, options) => {
		select.replaceChildren(
			...options.map(([value, label]) => {
				const option = document.createElement('option');
				option.value = value;
				option.textContent = label;
				return option;
			})
		);
		select.value = select.dataset.initial;
		if (select.selectedIndex === -1) select.selectedIndex = 0;
	};

	for (const container of document.querySelectorAll('.scrolling-record-list')) {
		const name = container.dataset.name;
		const recordSelect = document.getElementById(name);
		const sortSelect = document.getElementById(`${name}!sort`);
		const formatSelect = document.getElementById(`${name}!format`);
		const filterSelect = document.getElementById(`${name}!filter`);
		const intersectCheck = document.getElementById(`${name}!intersect_check`);
		const unionCheck = document.getElementById(`${name}!union_check`);

		const type = recordSelect.dataset.type;
		const records = JSON.parse(recordSelect.dataset.records);
		if (!type || !records.length) continue;

		fillSelect(sortSelect, sorts[type]);
		fillSelect(formatSelect, formats[type]);

		const recordMatches = (record, filter) => {
			const separator = filter.indexOf(':');
			return String(record.fields[filter.slice(0, separator)] ?? '') === filter.slice(separator + 1);
		};

		const filterRecords = () => {
			const filters = Array.from(filterSelect.selectedOptions, (option) => option.value);
			if (intersectCheck.checked) {
				const fieldFilters = filters.filter((filter) => filter !== 'all');
				return records.filter((record) => fieldFilters.every((filter) => recordMatches(record, filter)));
			}
			if (!filters.length || filters.includes('all')) return records;
			return records.filter((record) => filters.some((filter) => recordMatches(record, filter)));
		};

		const sortRecords = (list) => {
			const fields = sorts[type].find(([value]) => value === sortSelect.value)[2];
			return [...list].sort((a, b) => {
				for (const field of fields) {
					const result = collator.compare(a.fields[field] ?? '', b.fields[field] ?? '');
					if (result) return result;
				}
				return 0;
			});
		};

		const formatRecord = (record) =>
			formatSelect.selectedOptions[0].textContent.replace(/\w+/g, (word) =>
				Object.hasOwn(record.fields, word) ? (record.display?.[word] ?? record.fields[word] ?? '') : word
			);

		const updateList = (selected) => {
			const previousSelection = new Set(Array.from(recordSelect.selectedOptions, (option) => option.value));
			selected ??= previousSelection;

			recordSelect.replaceChildren(
				...sortRecords(filterRecords()).map((record) => {
					const option = document.createElement('option');
					option.value = record.value;
					option.textContent = formatRecord(record);
					option.selected = selected.has(record.value);
					return option;
				})
			);

			const currentSelection = Array.from(recordSelect.selectedOptions, (option) => option.value);
			if (
				currentSelection.length !== previousSelection.size ||
				currentSelection.some((value) => !previousSelection.has(value))
			)
				recordSelect.dispatchEvent(new Event('change'));
		};

		for (const control of [sortSelect, formatSelect, filterSelect, intersectCheck, unionCheck]) {
			control.addEventListener('change', () => updateList());
		}

		updateList(new Set(JSON.parse(recordSelect.dataset.selected)));
	}
})();
