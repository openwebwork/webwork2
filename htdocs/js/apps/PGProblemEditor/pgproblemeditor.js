(() => {
	// Add a container for message toasts.
	const toastContainer = document.createElement('div');
	toastContainer.classList.add('toast-container', 'position-fixed', 'bottom-0', 'end-0', 'p-3');
	toastContainer.style.zIndex = 20;
	document.body.append(toastContainer);

	// Convenience method for showing messages in a Bootstrap toast.
	const showMessage = (message, success = false) => {
		if (!message) return;

		const toast = document.createElement('div');
		toast.classList.add('toast', 'align-items-center', 'border-0');
		toast.setAttribute('role', 'alert');
		toast.setAttribute('aria-live', success ? 'polite' : 'assertive');
		toast.setAttribute('aria-atomic', 'true');
		toast.innerHTML = `<div class="d-flex alert ${success ? 'alert-success' : 'alert-danger'} p-0">` +
			`<div class="toast-body">${message}</div>` +
			'<button type="button" class="btn-close me-2 m-auto" data-bs-dismiss="toast" ' +
			'aria-label="Close"></button></div>';

		toastContainer.append(toast);

		const bsToast = new bootstrap.Toast(toast, { delay: success ? 2000 : 6000 });
		toast.addEventListener('hidden.bs.toast', () => { bsToast.dispose(); toast.remove(); })
		bsToast.show();
	};

	const webserviceURL = `${webworkConfig?.webwork_url ?? '/webwork2'}/instructor_rpc`;

	// Send a request to the server to save the temporary file for the currently edited file.
	// This temporary file could be used for recovery, and is displayed if the page is reloaded.
	const saveTempFile = () => {
		const request_object = {
			user: document.getElementById('hidden_user')?.value,
			courseID: document.getElementsByName('courseID')[0]?.value,
			key: document.getElementById('hidden_key')?.value
		};

		request_object.rpc_command = 'saveFile';
		request_object.outputFilePath = document.getElementsByName('temp_file_path')[0]?.value ?? '';
		request_object.fileContents = webworkConfig?.pgCodeMirror?.getValue()
			?? document.getElementById('problemContents')?.value ?? '';

		if (!request_object.outputFilePath) return;

		document.getElementById('revert-to-tmp-container')?.classList.remove('d-none');
		document.getElementById('revert-tab')?.classList.remove('disabled');
		const revertRadio = document.getElementById('action_revert_type_revert_id');
		if (revertRadio && revertRadio.disabled) {
			revertRadio.disabled = false;
			revertRadio.checked = true;
		}

		fetch(webserviceURL, { method: 'post', mode: 'same-origin', body: new URLSearchParams(request_object) })
			.then((response) => response.json())
			.then((data) => showMessage(data.server_response, data.result_data))
			.catch((err) => showMessage(`Error saving temporary file: ${err?.message ?? err}`));
	};

	const viewSeedInput = document.getElementById('action_view_seed_id');
	if (viewSeedInput) {
		document.getElementById('randomize_view_seed_id')?.addEventListener('click', async () => {
			viewSeedInput.value = Math.ceil(Math.random() * 9999);
			await render();

			saveTempFile();
		});
	}

	const hardcopySeedInput = document.getElementById('action_hardcopy_seed_id');
	if (hardcopySeedInput) {
		document.getElementById('randomize_hardcopy_seed_id')?.addEventListener('click', async () => {
			hardcopySeedInput.value = Math.ceil(Math.random() * 9999);
			await generateHardcopy();

			saveTempFile();
		});
	}

	const revertBackupCheck = document.getElementById('action_revert_type_backup_id');
	if (revertBackupCheck) {
		document.getElementById('action_revert_backup_time_id')
			?.addEventListener('change', () => revertBackupCheck.checked = true);
	}
	const deleteBackupCheck = document.getElementById('action_revert_type_delete_id');
	if (deleteBackupCheck) {
		document.getElementById('action_revert_delete_number_id')
			?.addEventListener('change', () => deleteBackupCheck.checked = true);
	}

	document.getElementById('submit_button_id')?.addEventListener('click', async (e) => {
		const actionView = document.getElementById('view');
		const editorForm = document.getElementById('editor');

		// Make sure this is reset on each click so that a new window isn't always opened once that has been done once.
		if (editorForm) editorForm.target = '_self';

		if (actionView && actionView.classList.contains('active')) {
			if (document.getElementById('newWindowView')?.checked) {
				document.getElementById('revert-tab')?.classList.remove('disabled');
				document.getElementById('revert-to-tmp-container')?.classList.remove('d-none');
				const revertRadio = document.getElementById('action_revert_type_revert_id');
				if (revertRadio && revertRadio.disabled) {
					revertRadio.disabled = false;
					revertRadio.checked = true;
				}

				if (editorForm) editorForm.target = 'WW_View';
			} else {
				e.preventDefault();
				await render();

				saveTempFile();
			}
		}

		const actionSave = document.getElementById('save');
		if (actionSave
			&& actionSave.classList.contains('active')
			&& document.getElementById('newWindowSave')?.checked
			&& editorForm)
		{
			if (document.getElementById('backupFile')?.checked) {
				document.getElementById('show-backups-comment')?.classList.remove('d-none');
				const deleteBackupCheck = document.getElementById('deleteBackup');
				if (deleteBackupCheck) deleteBackupCheck.disabled = false;
			}
			document.getElementById('revert-tab')?.classList.remove('disabled');

			editorForm.target = 'WW_View';
		}


		const actionHardcopy = document.getElementById('hardcopy');
		if (actionHardcopy && actionHardcopy.classList.contains('active')) {
			e.preventDefault();
			await generateHardcopy();

			saveTempFile();
		}
	});

	const renderURL = `${webworkConfig?.webwork_url ?? '/webwork2'}/render_rpc`;
	const renderArea = document.getElementById('pgedit-render-area');
	const fileType = document.getElementsByName('file_type')[0]?.value;

	// This is either the div created by the CodeMirror editor or the problemContents textarea in the case that
	// CodeMirror is disabled in localOverrides.conf.
	const editorArea = document.querySelector('.CodeMirror') ?? document.getElementById('problemContents');

	// Add hot key, ctrl-enter, to render the problem
	editorArea.addEventListener('keydown', async (e) => {
		if (e.ctrlKey && e.code === 'Enter') {
			e.preventDefault();
			await render();
			saveTempFile();
		}
	});

	// Synchronize the heights of the render area and the editor area for wide windows.
	if (editorArea && renderArea) {
		const codeMirrorResizeObserver = new ResizeObserver((entries) => {
			if (document.body.clientWidth < 992) return;

			for (const entry of entries) {
				if (entry.borderBoxSize) {
					// Note that the blockSize is the height (since width is not resizable).
					const height = Array.isArray(entry.borderBoxSize)
						? entry.borderBoxSize[0].blockSize
						: entry.borderBoxSize.blockSize;
					if (window.getComputedStyle(renderArea).getPropertyValue('height') !== `${height}px`)
						renderArea.style.height = `${height}px`;
					if (window.getComputedStyle(editorArea).getPropertyValue('height') !== `${height}px`) {
						if (webworkConfig?.pgCodeMirror) webworkConfig.pgCodeMirror.setSize('100%', `${height}px`);
						else editorArea.style.height = `${height}px`;
					}
				}
			}
		});
		codeMirrorResizeObserver.observe(editorArea);
		codeMirrorResizeObserver.observe(renderArea);
	}

	// Save the initial placeholder content of the render area so that it can be put back when a problem is reloaded.
	const placeholder = renderArea.querySelector('.placeholder');
	const iframe = document.createElement('iframe');
	iframe.title = 'Rendered content';
	iframe.id = 'pgedit-render-iframe';

	// Adjust the height of the iframe when the window is resized and when the iframe loads.
	const adjustIFrameHeight = () => {
		if (document.body.clientWidth < 992) {
			if (iframe.contentDocument)
				renderArea.style.height = `${iframe.contentDocument.documentElement.offsetHeight + 2}px`;
		} else renderArea.style.height = `${editorArea.offsetHeight}px`;
	};
	window.addEventListener('resize', adjustIFrameHeight);

	// When one of the problem form submit buttons is clicked, set the source for the problem in the
	// hidden problemSource input to the current contents of the CodeMirror editor so that changes
	// are immediate.
	iframe.addEventListener('load', () => {
		const problemForm = iframe.contentWindow.document.getElementById('problemMainForm');
		if (!problemForm) return;

		for (const button of problemForm.querySelectorAll('input[type="submit"]')) {
			button.addEventListener('click', (e) => {
				e.preventDefault();

				// FormData does not support the characters in raw problem source.  URLSearchParams does.
				// So extract the problem form data using the FormData object and construct the URLSearchParams object
				// with that.
				const requestData = new URLSearchParams(new FormData(problemForm));
				requestData.set('rawProblemSource', webworkConfig?.pgCodeMirror?.getValue()
					?? document.getElementById('problemContents')?.value ?? '');
				requestData.set('send_pg_flags', 1);
				requestData.set(button.name, button.value);
				requestData.set('set_id', document.getElementsByName('hidden_set_id')[0]?.value ?? 'Unknown Set');

				renderProblem(requestData);

				saveTempFile();
			});
		}

		adjustIFrameHeight();

		// Scroll to the top of the render window if the current scroll position is below that.
		const renderAreaRect = renderArea.getBoundingClientRect();
		if (renderAreaRect.top < 0) window.scrollBy(0, renderAreaRect.top);
	});

	const render = () => new Promise((resolve) => {
		if (fileType === 'hardcopy_header') {
			renderArea.innerHTML = '<div class="alert alert-danger p-1 m-2 fw-bold">' +
				'Hardcopy header contents can only be viewed in a new window.</div>';
			resolve();
			return;
		}

		if (fileType === 'course_info') {
			const contents = webworkConfig?.pgCodeMirror?.getValue();
			if (contents) renderArea.innerHTML = contents;
			else
				renderArea.innerHTML = '<div class="alert alert-danger p-1 m-2 fw-bold">The file has no content.</div>';

			// Typeset any math content that may be in the course info file.
			if (window.MathJax) {
				MathJax.startup.promise =
					MathJax.startup.promise.then(() => MathJax.typesetPromise(['#pgedit-render-area']));
			}

			resolve();
			return;
		}

		const isProblem = fileType && /problem/.test(fileType) ? 1 : 0;

		renderProblem(new URLSearchParams({
			user: document.getElementById('hidden_user')?.value,
			courseID: document.getElementsByName('courseID')[0]?.value,
			key: document.getElementById('hidden_key')?.value,
			problemSeed: document.getElementById('action_view_seed_id')?.value ?? 1,
			sourceFilePath: document.getElementsByName('edit_file_path')[0]?.value,
			rawProblemSource: webworkConfig?.pgCodeMirror?.getValue()
				?? document.getElementById('problemContents')?.value ?? '',
			outputformat: 'simple',
			showAnswerNumbers: 0,
			// The set id is really only needed by set headers to get the correct dates for the set.
			set_id: document.getElementsByName('hidden_set_id')[0]?.value ?? 'Unknown Set',
			// This should not be an actual problem number in the set.  If so the current user's seed for that problem
			// will be used instead of the seed from the editor form.
			probNum: 0,
			showHints: 1,
			showSolutions: 1,
			isInstructor: 1,
			noprepostambles: 1,
			processAnswers: 0,
			showPreviewButton: isProblem,
			showCheckAnswersButton: isProblem,
			showCorrectAnswersButton: isProblem,
			showFooter: 0,
			displayMode: document.getElementById('action_view_displayMode_id')?.value ?? 'MathJax',
			language: document.querySelector('input[name="hidden_language"]')?.value ?? 'en',
			send_pg_flags: 1
		})).then(() => resolve());
	});

	// This is used to protect against rapid successive clicks on the "Randomize Seed" or "Take Action" buttons.
	let rendering = false;

	const renderProblem = (body) => new Promise((resolve) => {
		if (rendering) { resolve(); return; }
		rendering = true;

		// Put the placeholder back until the problem finishes rendering.
		renderArea.replaceChildren(placeholder);

		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), 20000);

		fetch(renderURL, { method: 'post', mode: 'same-origin', signal: controller.signal, body })
			.then((response) => {
				clearTimeout(timeoutId);
				return response.json();
			})
			.then((data) => {
				// If the error is set, show that.
				if (data.error) throw data.error;
				// This generally shouldn't happen.
				if (!data.html) throw 'A server error occured.  The response had no content';

				renderArea.replaceChildren(iframe);
				iframe.srcdoc = data.html;

				if (data.pg_flags && data.pg_flags.comment) {
					// The problem has a comment, so show it.
					const container = document.createElement('div');
					container.classList.add('px-2', 'mb-2');
					container.innerHTML = data.pg_flags.comment;
					iframe.after(container);
				}

				iframe.addEventListener('load', () => { rendering = false; resolve(); }, { once: true });
			})
			.catch((err) => {
				renderArea.innerHTML = `<div class="alert alert-danger p-1 m-2 fw-bold">Rendering error: ${
					err?.message ?? err}</div>`;
				rendering = false;
				resolve();
			});
	});

	// Render the content when the page loads.
	render();

	const generateHardcopy = async () => {
		if (rendering) return;
		rendering = true;

		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), 30000);

		try {
			const response = await fetch(renderURL, {
				method: 'post',
				mode: 'same-origin',
				signal: controller.signal,
				body: new URLSearchParams({
					user: document.getElementById('hidden_user')?.value,
					courseID: document.getElementsByName('courseID')[0]?.value,
					key: document.getElementById('hidden_key')?.value,
					problemSeed: document.getElementById('action_hardcopy_seed_id')?.value ?? 1,
					sourceFilePath: document.getElementsByName('edit_file_path')[0]?.value,
					rawProblemSource: webworkConfig?.pgCodeMirror?.getValue()
						?? document.getElementById('problemContents')?.value ?? '',
					outputformat: document.getElementById('action_hardcopy_format_id')?.value ?? 'pdf',
					hardcopy_theme: document.getElementById('action_hardcopy_theme_id')?.value ?? 'oneColumn',
					// The set id is really only needed by set headers to get the correct dates for the set.
					set_id: document.getElementsByName('hidden_set_id')[0]?.value ?? 'Unknown Set',
					// This should not be an actual problem number in the set.  If so the current user's seed for that
					// problem will be used instead of the seed from the editor form.
					probNum: 0,
					showHints: 1,
					showSolutions: 1,
					WWcorrectAns: 1,
					isInstructor: 1,
					noprepostambles: 1,
					processAnswers: 1,
					displayMode: 'tex',
					view_problem_debugging_info: 1
				})
			});

			clearTimeout(timeoutId);

			if (!response.ok ||
				!response.headers.get('content-type') ||
				/text\/html/.test(response.headers.get('content-type')))
			{
				throw await response.text();
				return;
			}

			const data = await response.blob();

			const element = document.createElement('a');
			element.href = window.URL.createObjectURL(data);
			element.download = response.headers.get('content-disposition').split('=')[1];
			element.style.display = 'none';
			document.body.appendChild(element);
			element.click();
			document.body.removeChild(element);

			rendering = false;
		} catch (err) {
			if (typeof err === 'string') {
				renderArea.innerHTML = '<div class="alert alert-danger p-1 m-2 fw-bold">' +
					'<div>Hardcopy generation errors:</div>' +
					err.split('\n').reduce((acc, line) => acc += `<div>${line}</div>`, '');
			} else {
				renderArea.innerHTML = `<div class="alert alert-danger p-1 m-2 fw-bold">Hardcopy generation error: ${
					err?.message ?? err}</div>`;
			}
			rendering = false;
		};
	};
})();
