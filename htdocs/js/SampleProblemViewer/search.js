/*  This file handles the searching capabilities of the main Sample Problems
	webpage. It uses the package MiniSearch to do the serching by passing information
	about every page to be searched (macro POD and sample problems).
*/
(() => {
	const miniSearch = new MiniSearch({ fields: ['terms', 'filename', 'name', 'description', 'methods'] });
	let pages;
	// This is the data from sample-problems/macros POD.
	fetch('../../DATA/search.json')
		.then((res) => res.json())
		.then((p) => {
			pages = p;
			miniSearch.addAll(pages);
		})
		.catch((e) => console.error(e));

	const resultList = document.getElementById('searchResults');
	const searchBox = document.getElementById('searchDocs');
	document.getElementById('clearSearchButton').addEventListener('click', () => {
		searchBox.value = '';
		resultList.innerHTML = '';
	});

	const search = () => {
		const results = miniSearch.search(searchBox.value, { prefix: true });
		const ids = results.map((p) => p.id);

		const includeMacros = document.getElementById('includeMacros').checked;
		const includeSP = document.getElementById('includeSP').checked;

		resultList.innerHTML = '';

		ids.forEach((id) => {
			const p = pages[id - 1];
			if ((p.type == 'sample problem' && includeSP) || (p.type == 'macro' && includeMacros)) {
				const item = document.createElement('div');
				item.classList.add('card');

				const file = p.filename.replace('.pg', '');
				const path = p.type == 'sample problem' ? 'sampleproblems' : p.type == 'macro' ? 'pod' : '';

				// This is the search results for each page.

				item.innerHTML = `
					<div class="card-body">
						<h5 class="card-title">
							<a href=\"/webwork2/${path}/${p.dir}/${file}\">${p.name}</a>
							(${p.type})
						</h5>
						<p class="card-text">${p.description}</p>
					</div>
					`;

				resultList.appendChild(item);
			}
		});
		// If there are no results, say so
		if (resultList.children.length == 0) {
			const item = document.createElement('div');
			item.classList.add('alert', 'alert-info');
			item.innerHTML = 'No results found';
			resultList.append(item);
		}
	};

	searchBox.addEventListener('keypress', search);
})();
