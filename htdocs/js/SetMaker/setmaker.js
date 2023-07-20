(() => {
	const webworkURL = webworkConfig?.webwork_url ?? '/webwork2';
	const basicWebserviceURL = `${webworkURL}/instructor_rpc`;

	let unloading = false;
	window.addEventListener('beforeunload', () => unloading = true);

	// Informational alerts/errors
	const alertToast = (title, msg, good = false) => {
		if (unloading) return;

		const toastContainer = document.createElement('div');
		toastContainer.classList.add(
			'toast-container', 'position-fixed', 'top-50', 'start-50',  'translate-middle', 'p-3');
		toastContainer.style.zIndex = 20;
		toastContainer.innerHTML =
			'<div class="toast bg-white" role="alert" aria-live="assertive" aria-atomic="true">' +
			'<div class="toast-header">' +
			`<strong class="me-auto">${title}</strong>` +
			'<button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="close"></button>' +
			'</div>' +
			`<div class="toast-body alert ${good ? 'alert-success' : 'alert-danger'} mb-0 text-center">${msg}</div>` +
			'</div>';
		document.body.prepend(toastContainer);
		const bsToast = new bootstrap.Toast(toastContainer.firstElementChild);
		toastContainer.addEventListener('hidden.bs.toast', () => { bsToast.dispose(); toastContainer.remove(); })
		bsToast.show();
	};

	// This is a convenience method for attaching both a click and keydown handler to spans that are inert by default.
	const attachEventListeners = (button, handler) => {
		button.addEventListener('click', handler);
		button.addEventListener('keydown', (e) => {
			if (e.key === ' ' || e.key === 'Enter') {
				e.preventDefault();
				handler();
			}
		});
	};

	const init_webservice = (command) => {
		return {
			rpc_command: 'listLib',
			library_name: 'Library',
			command: 'buildtree',
			user: document.getElementById('hidden_user')?.value,
			key: document.getElementById('hidden_key')?.value,
			courseID: document.getElementsByName('hidden_course_id')[0]?.value,
			rpc_command: command
		};
	};

	// Content request handling

	const libSubjects = document.querySelector('select[name="library_subjects"]');
	const libChapters = document.querySelector('select[name="library_chapters"]');
	const libSections = document.querySelector('select[name="library_sections"]');
	const libraryTextbook = document.querySelector('select[name="library_textbook"]');
	const libraryChapter = document.querySelector('select[name="library_textchapter"]');
	const librarySection = document.querySelector('select[name="library_textsection"]');
	const includeOPL = document.querySelector('[name="includeOPL"]');
	const includeContrib = document.querySelector('[name="includeContrib"]');

	const countLine = document.getElementById('library_count_line');

	const lib_update = async (who, what) => {
		const child = { subjects: 'chapters', chapters: 'sections', sections: 'count' };

		const requestObject = init_webservice('searchLib');
		requestObject.library_subjects = libSubjects?.value ?? '';
		requestObject.library_chapters = libChapters?.value ?? '';
		requestObject.library_sections = libSections?.value ?? '';
		requestObject.library_textbook = libraryTextbook?.value ?? '';
		requestObject.library_textchapter = libraryChapter?.value ?? '';
		requestObject.library_textsection = librarySection?.value ?? '';
		requestObject.includeOPL = (includeOPL.type === 'checkbox' && includeOPL?.checked) ||
			(includeOPL.type === 'hidden' && includeOPL.value) ? 1 : 0;
		requestObject.includeContrib = includeContrib?.checked ? 1 : 0;

		if (who == 'count') {
			// Don't perform a count if there is no count line to update.
			if (!countLine) return;

			requestObject.command = 'countDBListings';

			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), 10000);

			try {
				const response = await fetch(basicWebserviceURL, {
					method: 'post',
					mode: 'same-origin',
					body: new URLSearchParams(requestObject),
					signal: controller.signal
				});

				clearTimeout(timeoutId);

				if (!response.ok) {
					throw 'Unknown server communication error.';
				} else {
					const data = await response.json();
					if (data.error) {
						throw data.error;
					} else {
						const num = data.result_data[0];
						countLine.firstElementChild.innerHTML = num === '1'
							? 'There is 1 matching WeBWorK problem'
							: `There are ${num} matching WeBWorK problems.`;
					}
				}
			} catch (e) {
				alertToast(basicWebserviceURL, e?.message ?? e);
			}
			return;
		}

		if (what == 'clear') {
			setselect(`library_${who}`, []);
			lib_update(child[who], 'clear');
			return;
		}

		if (who == 'chapters' && requestObject.library_subjects == '') { lib_update(who, 'clear'); return; }
		if (who == 'sections' && requestObject.library_chapters == '') { lib_update(who, 'clear'); return; }

		requestObject.command = who == 'sections' ? 'getSectionListings' : 'getAllDBchapters';

		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), 10000);

		try {
			const response = await fetch(basicWebserviceURL, {
				method: 'post',
				mode: 'same-origin',
				body: new URLSearchParams(requestObject),
				signal: controller.signal
			});

			clearTimeout(timeoutId);

			if (!response.ok) {
				throw 'Unknown server communication error.';
			} else {
				const data = await response.json();
				if (data.error) {
					throw data.error;
				} else {
					setselect(`library_${who}`, data.result_data);
					lib_update(child[who], 'clear');
				}
			}
		} catch (e) {
			alertToast(basicWebserviceURL, e?.message ?? e);
		}
	};

	const setselect = (selname, newarray) => {
		const sel = document.querySelector(`[name="${selname}"]`);
		// Save the 'all' option, remove all options, and then restore the 'all' option.
		const select_all_option = sel.firstChild;
		while (sel.firstChild) sel.lastChild.remove();
		sel.append(select_all_option);
		newarray.forEach((val) => {
			const option = document.createElement('option');
			option.value = val;
			option.textContent = val;
			sel.append(option);
		});
	};

	libChapters?.addEventListener('change', () => lib_update('sections', 'get'));
	libSubjects?.addEventListener('change', () => lib_update('chapters', 'get'));
	libSections?.addEventListener('change', () => lib_update('count', 'clear'));
	includeOPL?.addEventListener('change', () => lib_update('count', 'clear'));
	includeContrib?.addEventListener('change', () => lib_update('count', 'clear'));
	document.querySelectorAll('input[name="level"]').forEach(
		(level) => level.addEventListener('change', () => lib_update('count', 'clear')));

	// Set up the advanced view selects to submit the form when changed.
	const libraryBrowserForm = document.forms['library_browser_form'];
	if (libraryBrowserForm) {
		libraryTextbook?.addEventListener('change', () => libraryBrowserForm.submit());
		libraryChapter?.addEventListener('change', () => libraryBrowserForm.submit());
		librarySection?.addEventListener('change', () => libraryBrowserForm.submit());
	}

	// Add problems to target set
	const addme = async (path, who) => {
		const localSets = document.getElementById('local_sets');
		const target = localSets?.value;
		if (target === '') {
			alertToast(localSets?.dataset.noSetSelected ?? 'No Target Set Selected',
				localSets?.dataset.pickTargetSet ?? 'Pick a target set above to add this problem to.');
			return;
		}

		const request = init_webservice('addProblem');
		request.set_id = target;

		const pathlist = [];
		if (who == 'one') {
			pathlist.push(path);
		} else {
			// who == 'all'
			document.querySelectorAll('[name^="filetrial"]').forEach((prob) => pathlist.push(prob.value));
		}

		try {
			// The requests must be awaited in the for loop so that the problems are added in the correct order.
			// FIXME: It would be better to add a WebworkWebservice method to add multiple problems in one request.
			for (const path of pathlist) {
				request.problemPath = path;

				const controller = new AbortController();
				const timeoutId = setTimeout(() => controller.abort(), 10000);

				const response = await fetch(basicWebserviceURL, {
					method: 'post',
					mode: 'same-origin',
					body: new URLSearchParams(request),
					signal: controller.signal
				});

				clearTimeout(timeoutId);

				if (!response.ok) {
					throw 'Unknown server communication error.';
				} else {
					const data = await response.json();
					if (data.error) throw data.error;
				}
			}
		} catch (e) {
			alertToast(basicWebserviceURL, e?.message ?? e);
			return;
		}

		markinset();
		alertToast(localSets?.dataset.problemsAdded ?? 'Problems Added',
			(pathlist.length === 1 ? localSets?.dataset.addedToSingle : localSets?.dataset.addedToPlural)
			.replace(/{number}/, pathlist.length).replace(/{set}/, target.replaceAll('_', ' ')) ??
			`Added ${pathlist.length} problem${pathlist.length == 1 ? '' : 's'} to set ${
				target.replaceAll('_', ' ')}.`,
			true);
	};

	document.querySelector('.library-action-btn.add-all-btn')?.addEventListener('click', () => addme('', 'all'));
	document.querySelectorAll('button.add_me')
		.forEach((btn) => btn.addEventListener('click', () => addme(btn.dataset.sourceFile, 'one')));

	// Update the messages about which problems are in the current set.
	const markinset = async () => {
		const ro = init_webservice('listGlobalSetProblems');
		ro.set_id = document.getElementById('local_sets')?.value;
		ro.command = 'true';

		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), 10000);

		try {
			const response = await fetch(basicWebserviceURL, {
				method: 'post',
				mode: 'same-origin',
				body: new URLSearchParams(ro),
				signal: controller.signal
			})

			clearTimeout(timeoutId);

			if (response.ok) {
				const data = await response.json();
				if (data.error) {
					throw data.error;
				} else {
					const paths = data.result_data.map((problem) => problem.path);
					const shownProbs = document.querySelectorAll('[name^="filetrial"]');
					for (const shownProb of shownProbs) {
						const inset = document.getElementById(`inset${shownProb.name.replace('filetrial', '')}`);
						if (paths.includes(shownProb.value)) inset?.classList.remove('d-none');
						else inset?.classList.add('d-none');
					}
				}
			} else {
				throw 'Unknown server communication error.';
			}
		} catch (e) {
			alertToast(basicWebserviceURL, e?.message ?? e);
		}
	};

	document.getElementById('local_sets')?.addEventListener('change', markinset);

	// More/Less like this handling

	const findAPLindex = (path) => {
		let j = 0;
		while (document.querySelector(`[name="all_past_list${j}"]`).value !== path && j < 1000) ++j;
		if (j == 1000) alertToast('Error', `Cannot find ${path}`);
		return j;
	};

	const delFromPGList = (path) => {
		let j = findAPLindex(path) + 1;
		while (document.querySelector(`[name="all_past_list${j}"]`)) {
			document.querySelector(`[name="all_past_list${j - 1}"]`).value =
				document.querySelector(`[name="all_past_list${j}"]`).value;
			document.querySelector(`[name="all_past_mlt${j - 1}"]`).value =
				document.querySelector(`[name="all_past_mlt${j}"]`).value;
			++j;
		}
		--j;
		document.querySelector(`[name="all_past_list${j}"]`)?.remove();
		document.querySelector(`[name="all_past_mlt${j}"]`)?.remove();
	};

	const delrow = (num) => {
		const path = document.querySelector(`[name="filetrial${num}"]`)?.value ?? '';
		const APLindex = findAPLindex(path);
		const mymlt = document.querySelector(`[name="all_past_mlt${APLindex}"]`)?.value ?? 0;
		const mymltM = document.getElementById(`mlt${num}`);
		const mymltMtext = mymltM ? mymltM.textContent : 'L'; // Default to L so extra stuff is not deleted.

		document.getElementById(`pgrow${num}`)?.remove();
		delFromPGList(path);

		let cnt = 1;
		if (mymltM && mymltMtext == 'M') {
			// If the hidden problems are not shown, remove the entire mlt table.
			const table_num = num;
			let newmlt = document.querySelector(`[name="all_past_mlt${APLindex}"]`);
			while (newmlt && newmlt.value == mymlt) {
				++cnt;
				++num;
				delFromPGList(document.querySelector(`[name="filetrial${num}"]`)?.value);
				document.getElementById(`pgrow${num}`)?.remove();
				newmlt = document.querySelector(`[name="all_past_mlt${APLindex}"]`);
			}
			document.getElementById(`mlt-table${table_num}`)?.remove();
		} else if (mymltM && document.querySelectorAll(`.MLT${mymlt}`).length === 0) {
			// If the children problems have already all been removed, then just remove the mlt table.
			document.getElementById(`mlt-table${num}`)?.remove();
		} else if (mymltM && mymltMtext == 'L') {
			// If there are children and they have been shown, then make the first child the mlt parent.
			const mltTable = document.getElementById(`mlt-table${num}`);
			const new_num = mltTable.querySelector(`.MLT${mymlt}`).id.match(/pgrow([0-9]+)/)[1];
			mltTable.id = `mlt-table${new_num}`;
			mymltM.id = `mlt${new_num}`;
			mymltM.dataset.mltCnt = new_num;
			const nextProblem = document.getElementById(`pgrow${new_num}`);
			const iconContainer = nextProblem.querySelector(`.lb-problem-icons`);
			iconContainer.prepend(mymltM);
			nextProblem.classList.remove(`MLT${mymlt}`);
			nextProblem.classList.add(`NS${new_num}`);
		}

		// Update various variables in the page
		const totalshown = document.getElementById('totalshown');
		totalshown.textContent = document.getElementById('totalshown').textContent - 1;
		const lastind = document.querySelector('[name="last_index"]');
		lastind.value = lastind.value - cnt;
		const lastShownInput = document.querySelector('[name="last_shown"]');
		lastShownInput.value = lastShownInput.value - 1;
		if (lastShownInput.value < document.querySelector('[name="first_shown"]').value) {
			document.getElementById('what_shown').textContent = 'None';
		} else {
			const lastshown = document.getElementById('lastshown');
			lastshown.textContent = document.getElementById('lastshown').textContent - 1;
		}
	};

	document.querySelectorAll('.dont-show').forEach((button) =>
		attachEventListeners(button, () => {
			bootstrap.Tooltip.getInstance(button)?.hide();
			delrow(button.dataset.rowCnt);
		})
	);

	const togglemlt = async (cnt, noshowclass) => {
		const unshownAreas = document.querySelectorAll(`.${noshowclass}`);
		let count = unshownAreas.length;
		const lastshown = document.getElementById('lastshown');
		const n1 = lastshown.textContent;
		const totalshown = document.getElementById('totalshown');
		const n2 = totalshown.textContent;

		const mltIcon = document.getElementById(`mlt${cnt}`);
		if(mltIcon.textContent == 'M') {
			unshownAreas.forEach((area) => area.classList.remove('d-none'));
			// Render any problems that were hidden that have not yet been rendered.
			for (const area of unshownAreas) {
				const iframe = area.querySelector('iframe[id^="problem_render_area_"][id$="_iframe"]');
				if (iframe && iframe.iFrameResizer) iframe.iFrameResizer.resize();
				else await render(area.id.match(/^pgrow(\d+)/)[1]);
			}
			mltIcon.textContent = 'L';
			mltIcon.dataset.bsTitle = mltIcon.dataset.lessText;
			bootstrap.Tooltip.getInstance(mltIcon)?.dispose();
			new bootstrap.Tooltip(mltIcon, { fallbackPlacements: [] })
			count = -count;
		} else {
			unshownAreas.forEach((area) => area.classList.add('d-none'));
			mltIcon.textContent = 'M';
			mltIcon.dataset.bsTitle = mltIcon.dataset.moreText;
			bootstrap.Tooltip.getInstance(mltIcon)?.dispose();
			new bootstrap.Tooltip(mltIcon, { fallbackPlacements: [] })
		}
		lastshown.textContent = n1 - count;
		totalshown.textContent = n2 - count;

		const last_shown = document.querySelector('[name="last_shown"]');
		last_shown.value = last_shown.value - count;
	}

	document.querySelectorAll('.lb-mlt-parent').forEach((button) =>
		attachEventListeners(button, () => togglemlt(button.dataset.mltCnt, button.dataset.mltNoshowClass)));

	// Problem rendering
	const render = (id) => new Promise((resolve) => {
		const renderArea = document.getElementById(`problem_render_area_${id}`);
		if (!renderArea) { resolve(); return; }

		// Abort if the display mode is not set to None
		if (document.getElementById('problem_displaymode')?.value === 'None') {
			while (renderArea.firstChild) renderArea.firstChild.remove();
			resolve();
			return;
		}

		webworkConfig.renderProblem(renderArea, {
			sourceFilePath: renderArea.dataset.pgFile,
			problemSeed: Math.floor(Math.random() * 10000),
			showHints: document.querySelector('input[name="showHints"]')?.checked ? 1 : 0,
			showSolutions: document.querySelector('input[name="showSolutions"]')?.checked ? 1 : 0
		}).then(resolve);
	});

	// Find all render areas
	const renderAreas = document.querySelectorAll('.rpc_render_area');

	// Add the loading message to all render areas.
	for (const renderArea of renderAreas) {
		renderArea.innerHTML = 'Loading Please Wait...';
	}

	// Render all visible problems on the page
	(async () => {
		for (const renderArea of renderAreas) {
			const id = renderArea.id.match(/^problem_render_area_(\d+)/)[1];
			if (document.getElementById(`pgrow${id}`)?.classList.contains('d-none')) continue;
			await render(id);
		}
	})();

	// Set up the problem rerandomization buttons.
	document.querySelectorAll('.rerandomize_problem_button').forEach((button) =>
		attachEventListeners(button, () => render(button.dataset.targetProblem)));

	// Enable bootstrap popovers and tooltips.
	document.querySelectorAll('.info-button').forEach((popover) => new bootstrap.Popover(popover));
	document.querySelectorAll('.lb-problem-add [data-bs-toggle], .lb-problem-icons [data-bs-toggle=tooltip]')
		.forEach((el) => new bootstrap.Tooltip(el, { fallbackPlacements: [] }));
})();
