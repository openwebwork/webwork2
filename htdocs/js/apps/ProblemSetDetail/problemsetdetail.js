(function() {
	// This uses the nestedSortable jquery-ui module to drive the
	// problem list, if its enabled

	$('#psd_list').nestedSortable({
		handle: 'span.pdr_handle',
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

	$('.psd_view').tooltip();
	$('.psd_edit').tooltip();
	$('.pdr_render').tooltip();
	$('.pdr_grader').tooltip();
	$('.pdr_handle > i').tooltip();

	if ($('#psd_list').hasClass('disable_renumber')) {
		$('#psd_list').nestedSortable({ disabled:true});
	}

	// The actual expand collapse icon is controlled by css
	$('.pdr_collapse').on('click', function() {
		$(this).closest('li').toggleClass('mjs-nestedSortable-collapsed').toggleClass('mjs-nestedSortable-expanded');
		$(this).tooltip('destroy');
		if ($(this).closest('li').hasClass('mjs-nestedSortable-collapsed')) {
			$(this).tooltip({ title: $(this).attr('data-expand-text'), container: this });
		} else {
			$(this).tooltip({ title: $(this).attr('data-collapse-text'), container: this });
		}

	}).each(function() {
		$(this).tooltip({title:$(this).attr('data-expand-text'),
			container: this});
	});

	// This is for the render buttons
	$('.pdr_render').click(function(event) {
		event.preventDefault();
		var id = this.id.match(/^pdr_render_(\d+)/)[1];
		var renderArea = $('#psr_render_area_' + id);
		var iframe = renderArea.find('#psr_render_iframe_' + id);
		if (iframe[0] && iframe[0].iFrameResizer) {
			iframe[0].iFrameResizer.close();
		} else if (renderArea.html() != "") {
			renderArea.html('')
		} else {
			renderArea.html("Loading Please Wait...");
			render(id);
		}
	});

	$('#psd_render_all').click(async function (event) {
		event.preventDefault();
		var renderAreas = $('.psr_render_area');
		for (var renderArea of renderAreas) {
			$(renderArea).html('Loading Please Wait...');
			await render(renderArea.id.match(/^psr_render_area_(\d+)/)[1]);
		}
	});

	$('#psd_hide_all').click(function (event) {
		event.preventDefault();
		$('.psr_render_area').each(function() {
			var iframe = $(this).find('[id^=psr_render_iframe_]');
			if (iframe[0] && iframe[0].iFrameResizer) iframe[0].iFrameResizer.close();
		});
	});

	// This is for collapsing and expanding the tree
	$('#psd_expand_all').click(function (event) {
		event.preventDefault();
		$('li.psd_list_row').removeClass('mjs-nestedSortable-collapsed').addClass('mjs-nestedSortable-expanded');
		$('.pdr_collapse').each(function () {
			$(this).tooltip('destroy');
			$(this).tooltip({title:$(this).attr('data-collapse-text'),
				container:this});
		});
	});

	$('#psd_collapse_all').click(function (event) {
		event.preventDefault();
		$('li.psd_list_row').addClass('mjs-nestedSortable-collapsed').removeClass('mjs-nestedSortable-expanded');
		$('.pdr_collapse').each(function () {
			$(this).tooltip('destroy');
			$(this).tooltip({title:$(this).attr('data-expand-text'),
				container:this});
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

	$('#psd_renumber').click(function (event) {
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
		return new Promise(function(resolve, reject) {
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
			ro.extra_header_text = "<style>html{overflow-y:hidden;}body{padding:0;background:#f5f5f5;.container-fluid{padding:0px;}</style>";
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
