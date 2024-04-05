(() => {
	const setListContainer = document.getElementById('set-list-container');

	if (!setListContainer) return;

	const addSection = (type, title, contents) => {
		const isCollapsed = localStorage.getItem(`${settingStoreID}.collapsed.${type}`) === 'true';

		const accordion = document.createElement('div');
		accordion.classList.add('accordion', 'mb-3');

		const item = document.createElement('div');
		item.classList.add('accordion-item');

		const header = document.createElement('h2');
		header.classList.add('accordion-header');

		const button = document.createElement('button');
		button.classList.add('accordion-button', 'fs-5', 'fw-bold');
		if (isCollapsed) button.classList.add('collapsed');
		button.type = 'button';
		button.dataset.bsToggle = 'collapse';
		button.dataset.bsTarget = `#${type}-collapse`;
		button.setAttribute('aria-expanded', isCollapsed ? 'false' : 'true');
		button.setAttribute('aria-controls', `${type}-collapse`);
		button.textContent = title;
		header.append(button);

		const collapse = document.createElement('div');
		collapse.classList.add('accordion-collapse', 'collapse');
		if (!isCollapsed) collapse.classList.add('show');
		collapse.id = `${type}-collapse`;

		const body = document.createElement('div');
		body.classList.add('accordion-body', 'p-0');
		collapse.append(body);

		const list = document.createElement('ol');
		list.classList.add('list-group', 'list-group-flush', 'rounded-bottom');
		list.append(...contents);
		body.append(list);

		item.append(header, collapse);
		accordion.append(item);

		setListContainer.append(accordion);

		collapse.addEventListener('shown.bs.collapse', () =>
			localStorage.setItem(`${settingStoreID}.collapsed.${type}`, 'false')
		);
		collapse.addEventListener('hidden.bs.collapse', () =>
			localStorage.setItem(`${settingStoreID}.collapsed.${type}`, 'true')
		);
	};

	const setList = Array.from(setListContainer.querySelectorAll('.list-group-item'));
	const showByDateBtn = document.getElementById('show-by-date-btn');
	const showByTypeBtn = document.getElementById('show-by-type-btn');
	const settingStoreID = `WW.${document.getElementsByName('courseID')[0]?.value ?? 'unknownCourse'}.${
		document.getElementsByName('userName')[0]?.value ?? 'unknownUser'
	}.problem_list`;

	const displayByDate = () => {
		while (setListContainer.firstChild) setListContainer.firstChild.remove();

		for (const [type, fallbackTitle] of [
			['open', 'Open Assignments'],
			['not-open', 'Unopen Assignments'],
			['past-due', 'Past Due Assignments']
		]) {
			const section = addSection(
				type,
				showByDateBtn?.dataset[`${type}Title`] ?? fallbackTitle,
				setList
					.filter((set) => set.dataset.setStatus === type)
					.sort((a, b) => parseInt(a.dataset.urgencySortOrder) - parseInt(b.dataset.urgencySortOrder))
			);
		}

		localStorage.setItem(`${settingStoreID}.sort_method`, 'date');
		showByDateBtn.classList.add('active');
		showByTypeBtn.classList.remove('active');
	};

	const displayByType = () => {
		while (setListContainer.firstChild) setListContainer.firstChild.remove();

		for (const [type, fallbackTitle] of [
			['default', 'Regular Assignments'],
			['test', 'Tests/Quizzes']
		]) {
			addSection(
				type,
				showByTypeBtn?.dataset[`${type}Title`] ?? fallbackTitle,
				setList
					.filter((set) => set.dataset.setType === type)
					.sort((a, b) => parseInt(a.dataset.nameSortOrder) - parseInt(b.dataset.nameSortOrder))
			);
		}

		localStorage.setItem(`${settingStoreID}.sort_method`, 'type');
		showByTypeBtn.classList.add('active');
		showByDateBtn.classList.remove('active');
	};

	showByDateBtn?.addEventListener('click', displayByDate);
	showByTypeBtn?.addEventListener('click', displayByType);

	const sortMethod = localStorage.getItem(`${settingStoreID}.sort_method`);
	if (sortMethod === 'type') displayByType();
	else displayByDate();
})();
