(() => {
	// Convert snake_case names to dataset key names in camelCase.
	const toDatasetKey = (name) => name.replace(/_([a-z0-9])/gi, (_, chr) => chr.toUpperCase());

	document.querySelectorAll('[id$="!refresh"]').forEach((b) => {
		const selectName = b.id.replace(/!refresh$/, '');
		const selectSort = document.getElementById(`${selectName}!sort`);
		const selectFormat = document.getElementById(`${selectName}!format`);
		const selectFilters = document.getElementById(`${selectName}!filter`);
		const selectUnion = document.getElementById(`${selectName}!union_check`);
		const selectTemplate = document
			.getElementById(`${selectName}_template`)
			.content.getElementById(`${selectName}_all`);

		b.addEventListener('click', () => {
			const selectedFilters = Array.from(selectFilters.selectedOptions, (option) => option.value);
			const intersect = !selectUnion.checked;
			const showAll = !selectedFilters.length || (selectedFilters.includes('all') && !intersect);

			const formatOption = selectFormat.selectedOptions[0];
			const formatString = formatOption.dataset.formatString;
			const fieldOrder = formatOption.dataset.fieldOrder.split('!');

			const sortKey = toDatasetKey(selectSort.value);

			const options = [];

			for (const templateOption of selectTemplate.querySelectorAll('option')) {
				if (!showAll) {
					const matchesFilter = selectedFilters.map((filter) => {
						if (filter === 'all') {
							return true;
						}
						const separator = filter.indexOf(':');
						const name = separator === -1 ? filter : filter.slice(0, separator);
						const value = separator === -1 ? '' : filter.slice(separator + 1);
						return templateOption.dataset[toDatasetKey(name)] === value;
					});
					if (!(intersect ? matchesFilter.every(Boolean) : matchesFilter.some(Boolean))) continue;
				}

				const option = templateOption.cloneNode(true);

				let i = 0;
				option.textContent = formatString.replace(/%s/g, () => {
					const field = fieldOrder[i++];
					return (
						option.dataset[toDatasetKey(`formatted_${field}`)] ??
						option.dataset[toDatasetKey(field)] ??
						'%s'
					);
				});

				options.push(option);
			}

			options.sort((a, b) =>
				(a.dataset[sortKey] ?? '').toLowerCase().localeCompare((b.dataset[sortKey] ?? '').toLowerCase())
			);

			document.getElementById(selectName).replaceChildren(...options);
		});
	});
})();
