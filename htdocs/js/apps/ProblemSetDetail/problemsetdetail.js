(function() {
	// This uses the nestedSortable jquery-ui module to drive the
	// problem list, if its enabled

	$('#psd_list').nestedSortable({
		handle: '.pdr_handle',
		placeholder: 'pdr_placeholder',
		tolerance: 'intersect',
		toleranceElement: '> div',
		items: 'li.psd_list_row',
		opacity: '.1',
		forcePlaceholderSize: true,
		scrollSpeed: 40,
		scrollSensitivity: 30,
		tabSize: 30,
		isTree: true,
		startCollapsed: true,
		maxLevels: 6,
	});

	document.querySelectorAll('.psd_view,.psd_edit,.pdr_render,.pdr_grader,.pdr_handle > i').forEach(
		(el) => new bootstrap.Tooltip(el)
	);

	if ($('#psd_list').hasClass('disable_renumber')) {
		$('#psd_list').nestedSortable({ disabled:true});
	}

	// The actual expand collapse icon is controlled by css
	document.querySelectorAll('.pdr_collapse').forEach((collapse) => {
		collapse.tooltip = new bootstrap.Tooltip(collapse, { title: collapse.dataset.expandText, container: collapse });
		collapse.addEventListener('click', () => {
			$(collapse).closest('li')
				.toggleClass('mjs-nestedSortable-collapsed').toggleClass('mjs-nestedSortable-expanded');
			collapse.tooltip.dispose();
			if ($(collapse).closest('li').hasClass('mjs-nestedSortable-collapsed')) {
				collapse.tooltip =
					new bootstrap.Tooltip(collapse, { title: collapse.dataset.expandText, container: collapse });
			} else {
				collapse.tooltip =
					new bootstrap.Tooltip(collapse, { title: collapse.dataset.collapseText, container: collapse });
			}
		});
	});

	// This is for the render buttons
	document.querySelectorAll('.pdr_render').forEach((renderButton) => {
		renderButton.addEventListener('click', (event) => {
			event.preventDefault();
			const id = renderButton.id.match(/^pdr_render_(\d+)/)[1];
			const renderArea = document.getElementById(`psr_render_area_${id}`);
			const iframe = document.getElementById(`psr_render_iframe_${id}`);
			if (iframe && iframe.iFrameResizer) {
				iframe.iFrameResizer.close();
			} else if (renderArea.innerHTML != '') {
				renderArea.innerHTML = '';
			} else {
				collapsibles[id]?.show();
				renderArea.innerHTML = 'Loading Please Wait...';
				render(id);
			}
		});
	});

	$('#psd_render_all').on('click', async function (event) {
		event.preventDefault();
		Object.keys(collapsibles).forEach((row) => collapsibles[row].show());
		var renderAreas = $('.psr_render_area');
		for (var renderArea of renderAreas) {
			$(renderArea).html('Loading Please Wait...');
			await render(renderArea.id.match(/^psr_render_area_(\d+)/)[1]);
		}
	});

	$('#psd_hide_all').on('click', function (event) {
		event.preventDefault();
		$('.psr_render_area').each(function() {
			var iframe = $(this).find('[id^=psr_render_iframe_]');
			if (iframe[0] && iframe[0].iFrameResizer) iframe[0].iFrameResizer.close();
		});
	});

	const collapsibles = Array.from(document.querySelectorAll('.psd_list_row')).reduce((accum, row) => {
		const problemID = row.id.match(/^psd_list_(\d+)/)[1];
		accum[problemID] =
			new bootstrap.Collapse(document.getElementById(`pdr_details_${problemID}`), { toggle: false });
		return accum;
	}, {});

	document.getElementById('psd_expand_details')?.addEventListener('click', (event) => {
		event.preventDefault();
		Object.keys(collapsibles).forEach((row) => collapsibles[row].show());
	});

	document.getElementById('psd_collapse_details')?.addEventListener('click', (event) => {
		event.preventDefault();
		Object.keys(collapsibles).forEach((row) => collapsibles[row].hide());
	});

	// This is for collapsing and expanding the JITAR tree
	$('#psd_expand_all').on('click', function (event) {
		event.preventDefault();
		$('li.psd_list_row').removeClass('mjs-nestedSortable-collapsed').addClass('mjs-nestedSortable-expanded');
		document.querySelectorAll('.pdr_collapse').forEach((collapse) => {
			collapse.tooltip.dispose();
			collapse.tooltip =
				new bootstrap.Tooltip(collapse, { title: collapse.dataset.collapseText, container: collapse });
		});
	});

	$('#psd_collapse_all').on('click', function (event) {
		event.preventDefault();
		$('li.psd_list_row').addClass('mjs-nestedSortable-collapsed').removeClass('mjs-nestedSortable-expanded');
		document.querySelectorAll('.pdr_collapse').forEach((collapse) => {
			collapse.tooltip.dispose();
			collapse.tooltip =
				new bootstrap.Tooltip(collapse, { title: collapse.dataset.expandText, container: collapse });
		});
	});


	// This uses recursion to set the #prob_num_id fields to the
	// new position in the tree whenever the tree is updated or
	// the renumber button is clicked
	var recurse_on_hierarchy = function (hierarchy,array) {
		for (var i=0; i < hierarchy.length; i++) {
			var id = hierarchy[i].id;

			$('#prob_num_'+id).val(i+1);

			$('#psd_list_' + id).find('.pdr_handle > span').each(function() {
				$(this).html($(this).html() + (i + 1) + '.');
			});

			for (var j=0; j < array.length; j++) {
				if (array[j].id == id) {
					$('#prob_parent_id_'+id).val(array[j].parent_id);
				}
			}

			if (typeof hierarchy[i].children != 'undefined') {
				recurse_on_hierarchy(hierarchy[i].children,array);
			}
		}
	};

	// this sets the prob_num fields so that the correct number is passed
	// to WeBWorK as a parameter
	var set_prob_num_fields = function () {
		var array = $('#psd_list').nestedSortable("toArray");
		var hierarchy = $('#psd_list').nestedSortable("toHierarchy");

		$('.pdr_handle > span').html('');
		recurse_on_hierarchy(hierarchy,array);

		$('.pdr_handle > span').each(function() {
			$(this).html($(this).html().slice(0, -1));
		});
		disable_fields();
	};

	// This enables and disables problem fields that don't make sense
	// based on the position of the problem
	var disable_fields = function () {
		var array = $('#psd_list').nestedSortable("toArray");

		$('.psd_list_row').each(function () {
			var id = this.id.match(/^psd_list_(\d+)/)[1];

			// If it has children then attempts to open is enabled
			var has_children = false;
			for (var i = 0; i < array.length; i++) {
				if (!has_children && array[i].parent_id == id) {
					$('#problem\\.'+id+'\\.att_to_open_children_id').parents('tr:first').removeClass('hidden');
					has_children = true;
				} else if (array[i].id == id) {
					// If its a top level problem counts_for_parent is disabled
					if (!array[i].parent_id) {
						$('#problem\\.'+id+'\\.counts_parent_grade_id').parents('tr:first').addClass('hidden');
					} else {
						$('#problem\\.'+id+'\\.counts_parent_grade_id').parents('tr:first').removeClass('hidden');
					}
				}
			}
			if (!has_children) {
				$('#problem\\.'+id+'\\.att_to_open_children_id').parents('tr:first').addClass('hidden');
			}
		});
	}

	// Actually run disabled fields on page load.
	disable_fields();

	$('#psd_list').on('sortupdate', set_prob_num_fields);

	$('#psd_renumber').on('click', function (event) {
		event.preventDefault();
		set_prob_num_fields();
	});

	var basicWebserviceURL = "/webwork2/html2xml";

	// Render all problems on page load if requested.
	if ($('#auto_render').is(':checked')) {
		(async function() {
			var renderAreas = $('.psr_render_area');
			for (var renderArea of renderAreas) {
				$(renderArea).html('Loading Please Wait...');
				await render(renderArea.id.match(/^psr_render_area_(\d+)/)[1]);
			}
		})();
	}

	async function render(id) {
		return new Promise(function(resolve) {
			var renderArea = $('#psr_render_area_' + id);

			var ro = {
				userID: $('#hidden_user').val(),
				courseID: $('#hidden_course_id').val(),
				session_key: $('#hidden_key').val()
			};

			if (!(ro.userID && ro.courseID && ro.session_key)) {
				renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
					.text("Missing hidden credentials: user, session_key, courseID"));
				resolve();
				return;
			}

			if ($('#problem\\.' + id + '\\.problem_seed_id').length > 0) {
				ro.problemSeed = $('#problem\\.' + id + '\\.problem_seed_id').val();
			} else {
				ro.problemSeed = 1;
			}

			if ($('#problem\\.' + id + '\\.source_file_id').val()) {
				ro.sourceFilePath = $('#problem\\.' + id + '\\.source_file_id').val();
			} else {
				ro.sourceFilePath = $('#problem_' + id + '_default_source_file').val();
			}

			if (ro.sourceFilePath.startsWith('group')) {
				renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError'})
					.text("Problem source is drawn from a grouping set."));
				resolve();
				return;
			}

			var editForUserInputs = $('input[name=editForUser]');
			if (editForUserInputs.length == 1) ro.effectiveUser = editForUserInputs.val();

			var versionIDInput = $('#hidden_version_id');
			if (versionIDInput.length) ro.version_id = versionIDInput.val();

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
			ro.extra_header_text = '<style>' +
				'html{overflow-y:hidden;}body{padding:1px;background:#f5f5f5;}.container-fluid{padding:0px;}' +
				'</style>';
			if (window.location.port) ro.forcePortNumber = window.location.port;

			$.ajax({type:'post',
				url: basicWebserviceURL,
				data: ro,
				timeout: 10000, //milliseconds
			}).done(function (data) {
				// Give nicer file not found error
				if (/this problem file was empty/i.test(data)) {
					renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text('No Such File or Directory!'));
					resolve();
					return;
				}
				// Give nicer session timeout error
				if (/Can\'t authenticate -- session may have timed out/i.test(data) ||
					/Webservice.pm: Error when trying to authenticate./i.test(data)) {
					renderArea.html($('<div/>',{ style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text("Can't authenticate -- session may have timed out."));
					resolve();
					return;
				}
				// Give nicer problem rendering error
				if (/error caught by translator while processing problem/i.test(data) ||
					/error message for command: renderproblem/i.test(data)) {
					renderArea.html($('<div/>',{ style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text('There was an error rendering this problem!'));
					resolve();
					return;
				}

				var iframe = $("<iframe/>", { id: "psr_render_iframe_" + id });
				renderArea.html(iframe);
				iframe[0].style.border = 'none';
				iframe[0].srcdoc = data;
				iFrameResize({ checkOrigin: false, warningTimeout: 20000, scrolling: 'omit' }, iframe[0]);
				iframe[0].addEventListener('load', function() { resolve(); });
			}).fail(function (data) {
				renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
					.text(basicWebserviceURL + ': ' + data.statusText));
				resolve();
			});
		});
	}
})();
