(() => {
	// Hover action to show exact value of each bar.
	document.querySelectorAll('.bar_graph_bar').forEach((el) => new bootstrap.Tooltip(el, { trigger: 'hover' }));

	// Send a request to the webwork webservice and render a problem.
	const basicWebserviceURL = `${webworkConfig?.webwork_url ?? '/webwork2'}/render_rpc`;

	const render = () => new Promise((resolve) => {
		const renderArea = document.getElementById(`problem_render_area`);

		const ro = {
			user: document.getElementById('hidden_user')?.value,
			courseID: document.getElementById('hidden_course_id')?.value,
			key: document.getElementById('hidden_key')?.value,
			problemSeed: 1,
			outputformat: 'simple',
			showAnswerNumbers: 0,
			set_id: document.getElementById('hidden_set_id')?.value,
			probNum: document.getElementById('hidden_problem_id')?.value,
			sourceFilePath: document.getElementById('hidden_source_file')?.value,
			showHints: 1,
			showSolutions: 1,
			permissionLevel: 10,
			isInstructor: 1,
			noprepostambles: 1,
			processAnswer: 0,
			showFooter: 0,
			displayMode: document.getElementById('problem_displaymode')?.value ?? 'MathJax',
			language: document.querySelector('input[name="hidden_language"]')?.value ?? 'en',
			send_pg_flags: 1,
			extra_header_text: '<style>' +
				'html{overflow-y:hidden;}body{padding:1px;background:#f5f5f5;}.container-fluid{padding:0px;}' +
				'</style>',
		};

		if (ro.sourceFilePath.startsWith('group')) {
			renderArea.innerHTML = '<div class="alert alert-danger p-1 mb-0" style="font-weight:bold">'
				+ 'Problem source is drawn from a grouping set.</div>';
			resolve();
			return;
		}

		renderArea.innerHTML = '<div class="alert alert-success p-1">Loading Please Wait...</div>';

		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), 10000);

		fetch(
			basicWebserviceURL,
			{
				method: 'post',
				mode: 'same-origin',
				body: new URLSearchParams(ro),
				signal: controller.signal
			}
		).then((response) => {
			clearTimeout(timeoutId);
			return response.json();
		}).then((data) => {
			// If the error is set, show that.
			if (data.error) throw data.error;
			// This generally shouldn't happen.
			if (!data.html) throw 'A server error occured.  The response had no content';
			// Give nicer file not found error
			if (/this problem file was empty/i.test(data.html)) throw 'No Such File or Directory!';
			// Give nicer problem rendering error
			if ((data.pg_flags && data.pg_flags.error_flag) ||
				/error caught by translator while processing problem/i.test(data.html))
				throw 'There was an error rendering this problem!';

			const iframe = document.createElement('iframe');
			iframe.id = 'problem_render_iframe';
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
		}).catch((err) => {
			renderArea.innerHTML = `<div class="alert alert-danger p-1 mb-0 fw-bold">${err?.message ?? err}</div>`;
			resolve();
		});
	});

	const hide = () => {
		const iframe = document.getElementById('problem_render_iframe');
		if (iframe && iframe.iFrameResizer) iframe.iFrameResizer.close();
	};

	// Set up the render button.
	document.getElementById('problem_render_btn')?.addEventListener('click', () => {
		const btn = document.getElementById('problem_render_btn');
		if (btn.innerHTML == 'Render Problem') {
			btn.innerHTML = 'Hide Problem';
			render();
		} else {
			btn.innerHTML = 'Render Problem';
			hide();
		}
	});

})();
