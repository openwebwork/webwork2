(() => {
	// Send signs that answers were not entered by the student for flagging unusual answer submissions.
	const form = document.getElementById('problemMainForm');
	const problemBody = document.getElementById('problem_body');
	if (!form || !problemBody) return;

	const controls = Array.from(
		problemBody.querySelectorAll(
			'input[name]:not([type="hidden"]):not([type="button"]):not([type="submit"]), textarea[name], select[name]'
		)
	);
	const isToggle = (control) => control.type === 'checkbox' || control.type === 'radio';
	const getState = (control) =>
		control instanceof HTMLSelectElement
			? Array.from(control.options, (option) => option.selected).join()
			: isToggle(control)
				? control.checked
				: control.value;

	// Values restored by the browser are already present when this runs and are not counted as changes.
	const initialStates = new Map(controls.map((control) => [control, getState(control)]));

	const isChanged = (control) =>
		getState(control) !== initialStates.get(control) &&
		// MathQuill rewrites its answer inputs after the page loads, so also compare to the values the server sent.
		(control instanceof HTMLSelectElement || isToggle(control) || control.value !== control.defaultValue);

	let interacted = false;
	for (const type of ['keydown', 'beforeinput', 'paste', 'drop', 'compositionend', 'pointerdown']) {
		problemBody.addEventListener(
			type,
			(e) => {
				if (e.isTrusted) interacted = true;
			},
			{ capture: true }
		);
	}

	// The formdata event also occurs for form.submit(), which does not trigger a submit event.
	form.addEventListener('formdata', (e) => {
		const flags = [];
		if (!interacted && controls.some(isChanged)) flags.push('no_interaction');
		if (navigator.webdriver) flags.push('webdriver');
		e.formData.set('inputFlags', flags.join(','));
	});
})();

(() => {
	// Record that the in-browser checks notice was dismissed so that it is not shown again.
	const notice = document.getElementById('browser-checks-notice');
	const form = document.getElementById('problemMainForm');
	if (!notice || !form) return;

	notice.addEventListener('closed.bs.alert', () => {
		const params = new URLSearchParams();
		for (const name of ['user', 'key', 'courseID']) {
			const value = form.elements[name]?.value;
			if (value) params.set(name, value);
		}
		fetch(`${webworkConfig?.webwork_url ?? '/webwork2'}/api/dismissBrowserChecksNotice`, {
			method: 'post',
			mode: 'same-origin',
			body: params
		}).catch(() => {});
	});
})();
