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

	const layoutPopoversInClone = (clone, layout) => {
		const setStyles = (element, styles) => {
			for (const [name, value] of Object.entries(styles)) element.style.setProperty(name, value, 'important');
		};

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
					const [pseudoElementStyles, removePseudoElementMarks] = await getPseudoElementImageStyles();
					removeMarks.push(removePseudoElementMarks);
					return modernScreenshot.domToPng(problemBody, {
						scale: Math.min(Math.max(window.devicePixelRatio || 1, 1), 2),
						timeout: 10000,
						...(popoverLayout.numPopovers
							? {
									width: popoverLayout.width,
									height: popoverLayout.height,
									onCloneNode: (clone) => layoutPopoversInClone(clone, popoverLayout)
								}
							: {}),
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
