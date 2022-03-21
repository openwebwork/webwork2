(() => {
	// Use the sortablejs drag and drop library to drive the problem list.
	const container = document.getElementById('psd_list');

	// This tracks the x coordinate of the pointer during a drag and is used to restrict the dragged element from being
	// inserted into a sublist if the drag is not far enough to the right.
	let lastX = -1;

	const pointerMove = (evt) => {
		lastX = evt.clientX;
		const y = evt.clientY;

		// Look for a list item a little above the current pointer position.
		// If there is a collapsed list item there, then expand it.
		const elt = document.elementFromPoint(lastX, y - 50)?.closest('.psd_list_item');
		if (elt && Sortable.dragged && Sortable.dragged !== elt && elt.subList && elt.collapseButton
			&& lastX > elt.collapseButton.getBoundingClientRect().left)
			bootstrap.Collapse.getInstance(elt.subList).show();
	};

	const recursiveRenumber = (tree, parentId) => {
		for (let i = 0; i < tree.length; ++i) {
			const item = document.getElementById(tree[i]);
			if (!item) return;

			// Update the problem number fields to be returned to WeBWorK.
			document.getElementById(item.id.replace('psd_list_item_', 'prob_num_')).value = i + 1;
			document.getElementById(item.id.replace('psd_list_item_', 'prob_parent_id_')).value = parentId ?? '';

			// Update the displayed problem number for this problem and all children.
			item.querySelectorAll('.psd_list_item .pdr_problem_number')
				.forEach((itemNumber) => {
					itemNumber.textContent = itemNumber.textContent ? `${itemNumber.textContent}.${i + 1}`: (i + 1);
				});
			if (item.subList)
				recursiveRenumber(Sortable.get(item.subList).toArray(), item.id.replace('psd_list_item_', ''));
		}
	}

	const setProblemNumberFields = () => {
		container.querySelectorAll('.psd_list_item .pdr_problem_number').forEach((num) => num.textContent = '');
		recursiveRenumber(Sortable.get(container).toArray());
	};

	const setSortable = (list) => {
		// Set up the bootstrap collapses.  Note that if a list is empty, then the collapse is shown.  Since it is empty
		// you still see nothing, but dragging into the list is smoother because it doesn't need to be expanded first.
		if (list.classList.contains('collapse'))
			list.collapse = new bootstrap.Collapse(list, { toggle: !list.querySelector('.psd_list_item') })

		if (list.id === container.id) list.nestDepth = 0;
		else list.nestDepth = list.parentNode.closest('.sortable-branch').nestDepth + 1;

		let hiddenCollapse = null;

		new Sortable(list, {
			group: {
				name: 'psd_list',
				put: (to, from) => from.el.nestDepth > to.el.nestDepth ||
					lastX > to.el.parentNode.querySelector('.pdr_handle').getBoundingClientRect().right
			},
			handle: '.pdr_handle',
			draggable: '> .psd_list_item',
			dataIdAttr: 'id',
			scrollSpeed: 40,
			bubbleScroll: true,
			animation: 150,
			swapThreshold: 0.5,
			forceFallback: true,
			onStart(evt) {
				// Disable tooltips during a drag.
				container.querySelectorAll('[data-bs-toggle]').forEach(
					(tooltip) => bootstrap.Tooltip.getInstance(tooltip)?.disable()
				);

				// If the dragged item has a non-empty child list, then collapse it while dragging.
				if (evt.item.subList && evt.item.subList.classList.contains('show')
					&& evt.item.subList.querySelector('.psd_list_item')) {
					hiddenCollapse = bootstrap.Collapse.getInstance(evt.item.subList);
					hiddenCollapse.hide();
					evt.item.subList.addEventListener('shown.bs.collapse', () => hiddenCollapse = null, { once: true });
				}

				container.addEventListener('pointermove', pointerMove, { passive: true });
			},
			onEnd() {
				container.removeEventListener('pointermove', pointerMove, { passive: true });

				// Expand the dragged item if it was collapsed at the start.
				if (hiddenCollapse?._isTransitioning)
					hiddenCollapse._element.addEventListener('hidden.bs.collapse',
						() => hiddenCollapse?.show(), { once: true });
				else hiddenCollapse?.show();

				// Re-enable tooltips at the end of a drag.
				container.querySelectorAll('[data-bs-toggle]').forEach(
					(tooltip) => bootstrap.Tooltip.getInstance(tooltip)?.enable()
				);
			},
			onSort() {
				setProblemNumberFields();
				disableFields();
			},
			onRemove() {
				if (hiddenCollapse?._isTransitioning)
					hiddenCollapse._element.addEventListener('hidden.bs.collapse',
						() => hiddenCollapse?.show(), { once: true });
				else hiddenCollapse?.show();
			},
			onChange(evt) {
				container.querySelectorAll('.sortable-branch').forEach((list) => {
					if (list.firstElementChild) list.parentNode.collapseButton?.classList.remove('d-none');
					else list.parentNode.collapseButton?.classList.add('d-none');
				});
				if (evt.from.querySelectorAll('.psd_list_item').length < 2)
					evt.from.parentNode.collapseButton?.classList.add('d-none');
			}
		});
	};

	container?.querySelectorAll('.psd_list_item').forEach((elt) => {
		elt.subList = elt.querySelector('.sortable-branch');

		// Set up the buttons that expand/contract JITAR nesting.
		elt.collapseButton = elt.querySelector('.problem_detail_row').querySelector('.pdr_collapse');
		if (elt.collapseButton) {
			elt.collapseButton.tooltip = new bootstrap.Tooltip(elt.collapseButton.firstElementChild,
				{ title: elt.collapseButton.dataset.expandText, container: elt.collapseButton });

			elt.collapseButton.dataset.bsTarget = `#${elt.subList.id}`;

			const hasChildren = elt.subList.querySelector('.psd_list_item');
			if (!hasChildren) {
				elt.collapseButton.setAttribute('aria-expanded', true);
				elt.collapseButton.classList.remove('collapsed');
				elt.collapseButton.classList.add('d-none')
			};

			elt.collapseButton.setAttribute('aria-controls', elt.subList.id);

			elt.subList.addEventListener('hide.bs.collapse', () => {
				elt.collapseButton.tooltip.dispose();
				elt.collapseButton.tooltip = new bootstrap.Tooltip(elt.collapseButton.firstElementChild,
					{ title: elt.collapseButton.dataset.expandText, container: elt.collapseButton });
			});
			elt.subList.addEventListener('show.bs.collapse', () => {
				elt.collapseButton.tooltip.dispose();
				elt.collapseButton.tooltip = new bootstrap.Tooltip(elt.collapseButton.firstElementChild,
					{ title: elt.collapseButton.dataset.collapseText, container: elt.collapseButton });
				if (Sortable.dragged) elt.collapseButton.tooltip.disable();
			});
		}
	});

	if (container) setSortable(container);
	container?.querySelectorAll('.sortable-branch').forEach(setSortable);

	// Recursively convert the sortable list to a tree.  Each entry of the tree has the problem id, the parent id if it
	// has a parent, and a list of the child problems (each of which is again an entry of the tree).
	const addChildren = (item) => {
		const list = document.getElementById(`psd_sublist_${item.id}`);
		if (list) {
			const sortable = Sortable.get(list);
			if (sortable) {
				for (const id of sortable.toArray()) {
					const childItem = { id: id.replace('psd_list_item_', ''), parent: item.id, children: [] };
					item.children.push(childItem);
					addChildren(childItem);
				}
			}
		}
	};

	const toTree = () => {
		const tree = [];
		for (const id of Sortable.get(container).toArray()) {
			const item = { id: id.replace('psd_list_item_', ''), children: [] };
			tree.push(item);
			addChildren(item);
		}
		return tree;
	};

	// Initialize tooltips.
	document.querySelectorAll('.psd_view,.psd_edit,.pdr_render,.pdr_grader,.pdr_handle > i').forEach(
		(el) => new bootstrap.Tooltip(el)
	);

	// If editing for user(s), then disable drag and drop re-ordering of problems.
	if (document.getElementById('psd_list')?.classList.contains('disable_renumber')) {
		Sortable.get(container)?.option('disabled', true);
		container.querySelectorAll('.sortable-branch').forEach((list) =>
			Sortable.get(list)?.option('disabled', true));
	}

	// Set up the tooltips for the buttons that expand/contract details.
	document.querySelectorAll('.pdr_detail_collapse').forEach((button) => {
		const options = {
			title: button.dataset.collapseText,
			placement: 'top',
			offset: [-20, 0],
			fallbackPlacements: []
		};
		let tooltip = new bootstrap.Tooltip(button, options);
		const detailCollapse = document.getElementById(button.dataset.bsTarget.replace('#', ''));
		detailCollapse?.addEventListener('hide.bs.collapse', () => {
			tooltip.dispose();
			options.title = button.dataset.expandText;
			tooltip = new bootstrap.Tooltip(button, options);
		})
		detailCollapse?.addEventListener('show.bs.collapse', () => {
			tooltip.dispose();
			options.title = button.dataset.collapseText;
			tooltip = new bootstrap.Tooltip(button, options);
		})
	});

	// Set up the button to hide all rendered problems.
	document.getElementById('psd_hide_all')?.addEventListener('click', () => {
		document.querySelectorAll('.psr_render_area').forEach((renderArea) => {
			const iframe = renderArea.querySelector('[id^=psr_render_iframe_]');
			if (iframe && iframe.iFrameResizer) iframe.iFrameResizer.close();
		});
	}, { passive: true });

	// Initialize the problem details collapses.
	const collapsibles = Array.from(document.querySelectorAll('.psd_list_item')).reduce((accum, row) => {
		const problemID = row.id.match(/^psd_list_item_(\d+)/)[1];
		accum[problemID] =
			new bootstrap.Collapse(document.getElementById(`pdr_details_${problemID}`), { toggle: false });
		return accum;
	}, {});

	// Set up the details expand/collapse all buttons.
	document.getElementById('psd_expand_details')?.addEventListener('click', () => {
		Object.keys(collapsibles).forEach((row) => collapsibles[row].show());
	}, { passive: true });

	document.getElementById('psd_collapse_details')?.addEventListener('click', () => {
		Object.keys(collapsibles).forEach((row) => collapsibles[row].hide());
	}, { passive: true });

	// Set up the JITAR tree expand/collapse all buttons.
	document.getElementById('psd_expand_all')?.addEventListener('click', () => {
		document.querySelectorAll('.sortable-branch').forEach((branch) => {
			bootstrap.Collapse.getInstance(branch)?.show();
		});
	}, { passive: true });

	document.getElementById('psd_collapse_all')?.addEventListener('click', () => {
		document.querySelectorAll('.sortable-branch').forEach((branch) => {
			bootstrap.Collapse.getInstance(branch)?.hide();
		});
	}, { passive: true });

	// This enables and disables problem fields that don't make sense based on the position of the problem.
	const disableFields = (tree) => {
		for (const item of (tree ?? toTree())) {
			const countsForParentRow =
				document.getElementById(`problem.${item.id}.counts_parent_grade_id`)?.closest('tr');
			if (countsForParentRow) {
				if (item.parent) countsForParentRow.classList.remove('d-none');
				else countsForParentRow.classList.add('d-none');
			}

			const attToOpenChildrenRow =
				document.getElementById(`problem.${item.id}.att_to_open_children_id`)?.closest('tr');
			if (attToOpenChildrenRow) {
				if (item.children?.length) {
					attToOpenChildrenRow.classList.remove('d-none');
					disableFields(item.children);
				} else attToOpenChildrenRow.classList.add('d-none');
			}
		}
	}

	// Run disableFields on page load.
	if (container) disableFields();

	// Setup the renumber problems button.
	document.getElementById('psd_renumber')?.addEventListener('click', () => {
		setProblemNumberFields();
	}, { passive: true });

	// Send a request to the webwork webservice and render a problem.
	const basicWebserviceURL = '/webwork2/html2xml';

	const render = async (id) => {
		return new Promise(async (resolve) => {
			const renderArea = document.getElementById(`psr_render_area_${id}`);

			const ro = {
				userID: document.getElementById('hidden_user')?.value,
				courseID: document.getElementById('hidden_course_id')?.value,
				session_key: document.getElementById('hidden_key')?.value
			};

			if (!(ro.userID && ro.courseID && ro.session_key)) {
				renderArea.innerHTML = '<div class="alert alert-danger p-1 mb-0 fw-bold">'
					+ 'Missing hidden credentials: user, session_key, courseID</div>';
				resolve();
				return;
			}

			const problemSeed = document.getElementById(`problem.${id}.problem_seed_id`);
			ro.problemSeed = problemSeed ? problemSeed.value : 1;

			const sourceFile = document.getElementById(`problem.${id}.source_file_id`);
			ro.sourceFilePath =
				sourceFile ? sourceFile.value : document.getElementById(`problem_${id}_default_source_file`)?.value;

			if (ro.sourceFilePath.startsWith('group')) {
				renderArea.innerHTML = '<div class="alert alert-danger p-1 mb-0" style="font-weight:bold">'
					+ 'Problem source is drawn from a grouping set.</div>';
				resolve();
				return;
			}

			const editForUserInputs = document.querySelector('input[name=editForUser]');
			if (editForUserInputs) ro.effectiveUser = editForUserInputs.value;

			const versionIDInput = document.getElementById('hidden_version_id');
			if (versionIDInput) ro.version_id = versionIDInput.value;

			ro.outputformat = 'simple';
			ro.showAnswerNumbers = 0;
			ro.set_id = $('#hidden_set_id').val();
			ro.probNum = id;
			ro.showHints = 1;
			ro.showSolutions = 1;
			ro.permissionLevel = 10;
			ro.noprepostambles = 1;
			ro.processAnswers = 0;
			ro.showFooter = 0;
			ro.displayMode = $('#problem_displaymode').val();
			ro.send_pg_flags = 1;
			ro.extra_header_text = '<style>' +
				'html{overflow-y:hidden;}body{padding:1px;background:#f5f5f5;}.container-fluid{padding:0px;}' +
				'</style>';
			if (window.location.port) ro.forcePortNumber = window.location.port;
			if (document.documentElement.lang !== 'en-US') ro.language = document.documentElement.lang;

			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), 10000);

			const response = await fetch(
				basicWebserviceURL,
				{
					method: 'post',
					mode: 'same-origin',
					body: new URLSearchParams(ro),
					signal: controller.signal
				}
			);

			clearTimeout(timeoutId);

			if (response.ok) {
				const data = await response.json();

				// Give nicer session timeout error
				if (!data.html || /Can\'t authenticate -- session may have timed out/i.test(data.html) ||
					/Webservice.pm: Error when trying to authenticate./i.test(data.html)) {
					renderArea.innerHTML = '<div class="alert alert-danger p-1 mb-0 fw-bold">'
						+ "Can't authenticate -- session may have timed out.</div>";
					resolve();
					return;
				}
				// Give nicer file not found error
				if (/this problem file was empty/i.test(data.html)) {
					renderArea.innerHTML = '<div class="alert alert-danger p-1 mb-0 fw-bold">'
						+ 'No Such File or Directory!</div>';
					resolve();
					return;
				}
				// Give nicer problem rendering error
				if (data.pg_flags && data.pg_flags.error_flag  ||
					/error caught by translator while processing problem/i.test(data.html) ||
					/error message for command: renderproblem/i.test(data.html)) {
					renderArea.innerHTML = '<div class="alert alert-danger p-1 mb-0 fw-bold">'
						+ 'There was an error rendering this problem!</div>';
					resolve();
					return;
				}

				const iframe = document.createElement('iframe');
				iframe.id = `psr_render_iframe_${id}`;
				iframe.style.border = 'none';
				iframe.srcdoc = data.html;
				renderArea.innerHTML = '';
				renderArea.append(iframe);

				if (data.pg_flags && data.pg_flags.comment)
					iframe.insertAdjacentHTML('afterend', data.pg_flags.comment);
				if (data.warnings)
					iframe.insertAdjacentHTML('afterend', data.warnings);

				iFrameResize({ checkOrigin: false, warningTimeout: 20000, scrolling: 'omit' }, iframe);
				iframe.addEventListener('load', () => resolve());
			} else {
				renderArea.innerHTML = '<div class="alert alert-danger p-1 mb-0 fw-bold">'
					+ `${basicWebserviceURL}: ${data.statusText}` + '</div>';
				resolve();
			}
		});
	}

	// Set up the problem render buttons.
	document.querySelectorAll('.pdr_render').forEach((renderButton) => {
		renderButton.addEventListener('click', () => {
			const id = renderButton.id.match(/^pdr_render_(\d+)/)[1];
			const renderArea = document.getElementById(`psr_render_area_${id}`);
			const iframe = document.getElementById(`psr_render_iframe_${id}`);
			if (iframe && iframe.iFrameResizer) {
				iframe.iFrameResizer.close();
				renderArea.innerHTML = '';
			} else if (renderArea.innerHTML != '') {
				renderArea.innerHTML = '';
			} else {
				collapsibles[id]?.show();
				renderArea.innerHTML = '<div class="alert alert-success p-1 mb-0">Loading Please Wait...</div>';
				render(id);
			}
		}, { passive: true });
	});

	// Render all problems.
	const renderAll = async () => {
		Object.keys(collapsibles).forEach((row) => collapsibles[row].show());
		document.querySelectorAll('.sortable-branch.collapse').forEach(
			(branch) => bootstrap.Collapse.getInstance(branch)?.show());
		const renderAreas = document.querySelectorAll('.psr_render_area');
		for (const renderArea of renderAreas) {
			renderArea.innerHTML = '<div class="alert alert-success p-1 mb-0">Loading Please Wait...</div>';
		}
		for (const renderArea of renderAreas) {
			await render(renderArea.id.match(/^psr_render_area_(\d+)/)[1]);
		}
	};

	// Set up the render all button.
	document.getElementById('psd_render_all')?.addEventListener('click', () => {
		renderAll();
	}, { passive: true });

	// Render all problems on page load if requested.
	if (document.getElementById('auto_render')?.checked) renderAll();
})();
