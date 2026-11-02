(() => {
	// Cause achievement popups to appear and then go away
	document.querySelectorAll('.cheevo-toast').forEach((toast) => {
		const bsToast = new bootstrap.Toast(toast, { delay: 5000 });
		bsToast.show();
	});
})();

(() => {
	// Include a screenshot of the problem when the "Email Instructor" button is clicked.
	const feedbackForm = document.querySelector('form[data-screenshot-max-size]');
	const problemBody = document.getElementById('problem_body');
	const screenshotInput = feedbackForm?.querySelector('input[name="screenshot"]');
	if (!feedbackForm || !problemBody || !screenshotInput || !window.modernScreenshot) return;

	const imageToDataURL = async (url) => {
		const response = await fetch(url);
		if (!response.ok) throw new Error(`Failed to fetch ${url}.`);
		const blob = await response.blob();
		return new Promise((resolve, reject) => {
			const reader = new FileReader();
			reader.addEventListener('load', () => resolve(reader.result));
			reader.addEventListener('error', () => reject(reader.error));
			reader.readAsDataURL(blob);
		});
	};

	// Restore pseudo element images (such as the feedback button icons) that modern-screenshot does not copy correctly.
	const getPseudoElementImageStyles = async () => {
		const rules = [];
		const marked = [];
		for (const element of [problemBody, ...problemBody.querySelectorAll('*')]) {
			for (const pseudoElement of ['::before', '::after']) {
				let content = getComputedStyle(element, pseudoElement).content;
				if (!content.includes('url(')) continue;

				for (const [match, url] of content.matchAll(/url\("((?:[^"\\]|\\.)*)"\)/g)) {
					if (url.startsWith('data:')) continue;
					const dataURL = await imageToDataURL(url.replace(/\\(.)/g, '$1')).catch(() => null);
					content = content.replace(match, dataURL ? `url("${dataURL}")` : '""');
				}

				if (!element.dataset.screenshotPseudo) {
					element.dataset.screenshotPseudo = marked.length.toString();
					marked.push(element);
				}
				rules.push(
					`[data-screenshot-pseudo="${element.dataset.screenshotPseudo}"]${pseudoElement} ` +
						`{ content: ${content} !important; }`
				);
			}
		}
		return [rules.join('\n'), () => marked.forEach((element) => delete element.dataset.screenshotPseudo)];
	};

	// Include open popovers in the screenshot at the same place they are on the page.
	const getPopoverLayout = () => {
		const bodyRect = problemBody.getBoundingClientRect();
		const area = { top: bodyRect.top, left: bodyRect.left, bottom: bodyRect.bottom, right: bodyRect.right };

		const popovers = Array.from(problemBody.querySelectorAll('.popover')).filter(
			(popover) => popover.getBoundingClientRect().width > 0
		);
		for (const element of popovers.flatMap((popover) => [popover, ...popover.querySelectorAll('.popover-arrow')])) {
			const rect = element.getBoundingClientRect();
			area.top = Math.min(area.top, rect.top);
			area.left = Math.min(area.left, rect.left);
			area.bottom = Math.max(area.bottom, rect.bottom);
			area.right = Math.max(area.right, rect.right);
		}

		const bodyStyle = getComputedStyle(problemBody);
		const borderTop = parseFloat(bodyStyle.borderTopWidth);
		const borderLeft = parseFloat(bodyStyle.borderLeftWidth);

		const repositionedPopovers = popovers.filter(
			(popover) => popover.offsetParent === problemBody || !problemBody.contains(popover.offsetParent)
		);

		return [
			{
				numPopovers: popovers.length,
				width: Math.ceil(area.right - area.left),
				height: Math.ceil(area.bottom - area.top),
				padding: {
					top: parseFloat(bodyStyle.paddingTop) + bodyRect.top - area.top,
					left: parseFloat(bodyStyle.paddingLeft) + bodyRect.left - area.left,
					bottom: parseFloat(bodyStyle.paddingBottom) + area.bottom - bodyRect.bottom,
					right: parseFloat(bodyStyle.paddingRight) + area.right - bodyRect.right
				},
				popoverPositions: repositionedPopovers.map((popover, index) => {
					popover.dataset.screenshotPopover = index.toString();
					const rect = popover.getBoundingClientRect();
					return { top: rect.top - area.top - borderTop, left: rect.left - area.left - borderLeft };
				})
			},
			() => repositionedPopovers.forEach((popover) => delete popover.dataset.screenshotPopover)
		];
	};

	const setStyles = (element, styles) => {
		for (const [name, value] of Object.entries(styles)) element.style.setProperty(name, value, 'important');
	};

	const layoutPopoversInClone = (clone, layout) => {
		setStyles(clone, {
			position: 'relative',
			'box-sizing': 'border-box',
			width: `${layout.width}px`,
			height: `${layout.height}px`,
			'padding-top': `${layout.padding.top}px`,
			'padding-left': `${layout.padding.left}px`,
			'padding-bottom': `${layout.padding.bottom}px`,
			'padding-right': `${layout.padding.right}px`
		});

		layout.popoverPositions.forEach((position, index) => {
			const popover = clone.querySelector(`[data-screenshot-popover="${index}"]`);
			if (!popover) return;
			setStyles(popover, {
				position: 'absolute',
				inset: 'auto',
				top: `${position.top}px`,
				left: `${position.left}px`,
				transform: 'none',
				margin: '0'
			});
		});
	};

	const checkImages = {
		checkbox:
			"url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20'%3e%3cpath " +
			"fill='none' stroke='%23fff' stroke-linecap='round' stroke-linejoin='round' stroke-width='3' " +
			"d='m6 10 3 3 6-6'/%3e%3c/svg%3e\")",
		radio:
			"url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='-4 -4 8 8'%3e" +
			"%3ccircle r='2' fill='%23fff'/%3e%3c/svg%3e\")"
	};

	// Record checkbox, radio button, and select states since they are not rendered correctly in the screenshot.
	const getFormState = () => {
		const inputs = Array.from(problemBody.querySelectorAll('input[type="checkbox"], input[type="radio"]')).filter(
			(input) => input.getClientRects().length
		);
		const options = Array.from(problemBody.querySelectorAll('option'));
		for (const option of options) option.dataset.screenshotSelected = option.selected ? '1' : '0';
		return [
			inputs.map((input, index) => {
				input.dataset.screenshotInput = index.toString();
				const rect = input.getBoundingClientRect();
				const style = getComputedStyle(input);
				return {
					type: input.type,
					checked: input.checked,
					styles: Object.fromEntries([
						['width', `${rect.width}px`],
						['height', `${rect.height}px`],
						...[
							'margin-top',
							'margin-right',
							'margin-bottom',
							'margin-left',
							'vertical-align',
							'box-shadow'
						].map((name) => [name, style.getPropertyValue(name)])
					])
				};
			}),
			() => {
				for (const input of inputs) delete input.dataset.screenshotInput;
				for (const option of options) delete option.dataset.screenshotSelected;
			}
		];
	};

	const setFormStateInClone = (clone, inputStates) => {
		for (const option of clone.querySelectorAll('[data-screenshot-selected]'))
			option.toggleAttribute('selected', option.dataset.screenshotSelected === '1');

		for (const input of clone.querySelectorAll('[data-screenshot-input]')) {
			const state = inputStates[parseInt(input.dataset.screenshotInput)];
			if (!state) continue;
			const replacement = document.createElement('span');
			setStyles(replacement, {
				display: 'inline-block',
				'box-sizing': 'border-box',
				...state.styles,
				border: `1px solid ${state.checked ? '#0d6efd' : '#767676'}`,
				'border-radius': state.type === 'radio' ? '50%' : '0.25em',
				'background-color': state.checked ? '#0d6efd' : '#fff',
				'background-image': state.checked ? checkImages[state.type] : 'none',
				'background-size': 'contain',
				'background-repeat': 'no-repeat',
				'background-position': 'center'
			});
			input.replaceWith(replacement);
		}
	};

	let screenshotTaken = false;

	feedbackForm.addEventListener('submit', async (e) => {
		if (screenshotTaken) return;
		e.preventDefault();

		const submitter =
			e.submitter instanceof HTMLButtonElement || e.submitter instanceof HTMLInputElement ? e.submitter : null;
		if (submitter) submitter.disabled = true;

		const removeMarks = [];
		try {
			// Don't let a stalled screenshot prevent the feedback page from opening.
			const dataURL = await Promise.race([
				(async () => {
					const [popoverLayout, removePopoverMarks] = getPopoverLayout();
					removeMarks.push(removePopoverMarks);
					const [inputStates, removeFormStateMarks] = getFormState();
					removeMarks.push(removeFormStateMarks);
					const [pseudoElementStyles, removePseudoElementMarks] = await getPseudoElementImageStyles();
					removeMarks.push(removePseudoElementMarks);
					return modernScreenshot.domToPng(problemBody, {
						scale: Math.min(Math.max(window.devicePixelRatio || 1, 1), 2),
						timeout: 10000,
						...(popoverLayout.numPopovers
							? { width: popoverLayout.width, height: popoverLayout.height }
							: {}),
						onCloneNode: (clone) => {
							setFormStateInClone(clone, inputStates);
							if (popoverLayout.numPopovers) layoutPopoversInClone(clone, popoverLayout);
						},
						onCreateForeignObjectSvg: (svg) => {
							const style = document.createElement('style');
							// Prevent MathJax output from being clipped.
							style.textContent = `foreignObject svg { overflow: visible; }\n${pseudoElementStyles}`;
							svg.append(style);
						}
					});
				})(),
				new Promise((_resolve, reject) =>
					setTimeout(() => reject(new Error('Timed out taking screenshot of problem.')), 15000)
				)
			]);

			if (dataURL.length * 0.75 <= parseInt(feedbackForm.dataset.screenshotMaxSize))
				screenshotInput.value = dataURL;
		} catch (err) {
			console.error(err);
		} finally {
			for (const removeMarksFunc of removeMarks) removeMarksFunc();
		}

		if (submitter) submitter.disabled = false;
		screenshotTaken = true;
		feedbackForm.requestSubmit(submitter);
		// Take a new screenshot if this page is returned to with the back button.
		screenshotTaken = false;
	});
})();
