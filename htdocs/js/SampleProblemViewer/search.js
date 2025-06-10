/*  This file handles the searching capabilities of the main Sample Problems
	webpage. It uses the package MiniSearch to do the serching by passing information
	about every page to be searched (macro POD and sample problems).
*/
(() => {
	// ChatGPT generated throttle function similar to Lodash.
	function throttle(func, wait) {
		let lastCallTime = 0;
		let timeout = null;
		let lastArgs, lastContext;

		return function throttled(...args) {
			const now = Date.now();
			const remaining = wait - (now - lastCallTime);

			lastArgs = args;
			lastContext = this;

			if (remaining <= 0 || remaining > wait) {
				if (timeout) {
					clearTimeout(timeout);
					timeout = null;
				}
				lastCallTime = now;
				func.apply(lastContext, lastArgs);
			} else if (!timeout) {
				timeout = setTimeout(() => {
					lastCallTime = Date.now();
					timeout = null;
					func.apply(lastContext, lastArgs);
				}, remaining);
			}
		};
	}

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

	const search = throttle(() => {
		const results = miniSearch.search(searchBox.value);
		const ids = results.map((p) => p.id);

		resultList.innerHTML = '';
		ids.forEach((id) => {
			const item = document.createElement('div');
			item.classList.add('card');
			const p = pages[id - 1];
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
		});
	}, 250);

	searchBox.addEventListener('keypress', search);
})();
