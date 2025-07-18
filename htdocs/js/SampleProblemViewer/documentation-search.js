(async () => {
	const searchBox = document.getElementById('search-box');
	const resultList = document.getElementById('result-list');
	if (!resultList || !searchBox) return;

	const webwork2URL = webworkConfig?.webwork_url ?? '/webwork2';

	let searchData;
	try {
		const result = await fetch(`${webwork2URL}/sampleproblems/search_data`);
		searchData = await result.json();
	} catch (e) {
		console.log(e);
		return;
	}

	const miniSearch = new MiniSearch({
		fields: ['filename', 'name', 'description', 'terms', 'macros', 'subjects'],
		storeFields: ['type', 'filename', 'dir', 'description']
	});
	miniSearch.addAll(searchData);

	const searchMacrosCheck = document.getElementById('search-macros');
	const searchSampleProblemsCheck = document.getElementById('search-sample-problems');

	document.getElementById('clear-search-button')?.addEventListener('click', () => {
		searchBox.value = '';
		while (resultList.firstChild) resultList.firstChild.remove();
	});

	const searchDocumentation = () => {
		const searchMacros = searchMacrosCheck?.checked;
		const searchSampleProblems = searchSampleProblemsCheck?.checked;

		while (resultList.firstChild) resultList.firstChild.remove();

		if (!searchBox.value) return;

		for (const result of miniSearch.search(searchBox.value, { prefix: true })) {
			if (
				(searchSampleProblems && result.type === 'sample problem') ||
				(searchMacros && result.type === 'macro')
			) {
				const link = document.createElement('a');
				link.classList.add('list-group-item', 'list-group-item-action');
				link.href = `${webwork2URL}/${
					result.type === 'sample problem' ? 'sampleproblems' : result.type === 'macro' ? 'pod' : ''
				}/${result.dir}/${result.filename.replace('.pg', '')}`;

				const linkText = document.createElement('span');
				linkText.classList.add('h4');
				linkText.textContent = `${result.filename} (${result.type})`;
				link.append(linkText);

				if (result.description) {
					const summary = document.createElement('div');
					summary.textContent = result.description;
					link.append(summary);
				}

				resultList.append(link);
			}
		}

		if (resultList.children.length == 0) {
			const item = document.createElement('div');
			item.classList.add('alert', 'alert-info');
			item.innerHTML = 'No results found';
			resultList.append(item);
		}
	};

	searchBox.addEventListener('keyup', searchDocumentation);
	searchMacrosCheck?.addEventListener('change', searchDocumentation);
	searchSampleProblemsCheck?.addEventListener('change', searchDocumentation);
})();
