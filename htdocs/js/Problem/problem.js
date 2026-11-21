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
		try {
			const response = await fetch(url);
			if (!response.ok) return null;
			const blob = await response.blob();
			return await new Promise((resolve, reject) => {
				const reader = new FileReader();
				reader.addEventListener('load', () => resolve(reader.result));
				reader.addEventListener('error', () => reject(reader.error));
				reader.readAsDataURL(blob);
			});
		} catch {
			return null;
		}
	};

	const createMarker = () => {
		const marks = [];
		return {
			mark: (element, key, value) => marks.push([element, key, value]),
			apply: () => marks.forEach(([element, key, value]) => (element.dataset[key] = value)),
			remove: () => marks.forEach(([element, key]) => delete element.dataset[key])
		};
	};

	const urlPattern = /url\("((?:[^"\\]|\\.)*)"\)/g;

	// modern-screenshot does not copy pseudo element images.
	const getPseudoElementImageStyles = async (entries, mark) => {
		const dataURLs = new Map();
		for (const { content } of entries) {
			for (const [, url] of content.matchAll(urlPattern)) {
				if (url.startsWith('data:') || dataURLs.has(url)) continue;
				dataURLs.set(url, imageToDataURL(url.replace(/\\(.)/g, '$1')));
			}
		}
		for (const [url, dataURL] of dataURLs) dataURLs.set(url, await dataURL);

		const indices = new Map();
		return entries
			.map(({ element, pseudoElement, content }) => {
				if (!indices.has(element)) {
					indices.set(element, indices.size.toString());
					mark(element, 'screenshotPseudo', indices.get(element));
				}
				content = content.replace(urlPattern, (match, url) => {
					if (url.startsWith('data:')) return match;
					const dataURL = dataURLs.get(url);
					return dataURL ? `url("${dataURL}")` : '""';
				});
				const selector = `[data-screenshot-pseudo="${indices.get(element)}"]${pseudoElement}`;
				return `${selector} { content: ${content} !important; }`;
			})
			.join('\n');
	};

	// Keep open popovers where they are on the page.
	const getPopoverLayout = (mark) => {
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

		return {
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
				mark(popover, 'screenshotPopover', index.toString());
				const rect = popover.getBoundingClientRect();
				return { top: rect.top - area.top - borderTop, left: rect.left - area.left - borderLeft };
			})
		};
	};

	const setStyles = (element, styles) => {
		for (const [name, value] of Object.entries(styles)) element.style.setProperty(name, value, 'important');
	};

	// WebKit offsets box shadows in the screenshot.
	const isWebKit = /AppleWebKit/.test(navigator.userAgent) && !/Chrome|Chromium/.test(navigator.userAgent);

	const boxShadowReplacement = (boxShadow) => {
		const styles = { 'box-shadow': 'none' };
		let maxSpread = 0;
		for (const shadow of boxShadow.split(/,(?![^(]*\))/)) {
			if (shadow.includes('inset')) continue;
			const color = shadow.match(/(?:rgba?|hsla?|color)\([^)]*\)|#[\da-f]+/i)?.[0];
			const lengths = (shadow.replace(/\([^)]*\)/g, '').match(/-?[\d.]+px/g) ?? []).map(parseFloat);
			if (!color || lengths.length !== 4 || lengths.slice(0, 3).some((length) => length !== 0)) continue;
			if (lengths[3] > maxSpread) {
				maxSpread = lengths[3];
				Object.assign(styles, { outline: `${maxSpread}px solid ${color}`, 'outline-offset': '0' });
			}
		}
		return styles;
	};

	const scanElements = (mark) => {
		const pseudoElements = [];
		const boxShadowStyles = [];
		for (const element of [problemBody, ...problemBody.querySelectorAll('*')]) {
			for (const pseudoElement of ['::before', '::after']) {
				const content = getComputedStyle(element, pseudoElement).content;
				if (content.includes('url(')) pseudoElements.push({ element, pseudoElement, content });
			}
			if (!isWebKit || element === problemBody) continue;
			const boxShadow = getComputedStyle(element).boxShadow;
			if (!boxShadow || boxShadow === 'none') continue;
			mark(element, 'screenshotShadow', boxShadowStyles.length.toString());
			boxShadowStyles.push(boxShadowReplacement(boxShadow));
		}
		return { pseudoElements, boxShadowStyles };
	};

	const setBoxShadowsInClone = (clone, boxShadowStyles) => {
		for (const element of clone.querySelectorAll('[data-screenshot-shadow]')) {
			const styles = boxShadowStyles[parseInt(element.dataset.screenshotShadow)];
			if (styles) setStyles(element, styles);
		}
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

	// Form control states are not copied.
	const getFormState = (mark) => {
		for (const option of problemBody.querySelectorAll('option'))
			mark(option, 'screenshotSelected', option.selected ? '1' : '0');

		const inputs = Array.from(problemBody.querySelectorAll('input[type="checkbox"], input[type="radio"]')).filter(
			(input) => input.getClientRects().length
		);
		return inputs.map((input, index) => {
			mark(input, 'screenshotInput', index.toString());
			const rect = input.getBoundingClientRect();
			const style = getComputedStyle(input);
			return {
				type: input.type,
				checked: input.checked,
				styles: {
					width: `${rect.width}px`,
					height: `${rect.height}px`,
					'margin-top': style.marginTop,
					'margin-right': style.marginRight,
					'margin-bottom': style.marginBottom,
					'margin-left': style.marginLeft,
					'vertical-align': style.verticalAlign,
					...(isWebKit ? boxShadowReplacement(style.boxShadow) : { 'box-shadow': style.boxShadow })
				}
			};
		});
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

	// Plotly WebGL plots are blank when copied.
	const getPlotImages = async (mark, scale) => {
		const plots = window.Plotly ? Array.from(problemBody.querySelectorAll('.js-plotly-plot')) : [];
		const images = [];
		for (const plot of plots) {
			const rect = plot.getBoundingClientRect();
			if (!rect.width || !rect.height) continue;
			const image = await window.Plotly.toImage(plot, {
				format: 'png',
				width: rect.width,
				height: rect.height,
				scale
			}).catch(() => null);
			if (!image) continue;
			mark(plot, 'screenshotPlot', images.length.toString());
			images.push({ plot, image });
		}
		return images;
	};

	const setPlotImagesInClone = (clone, images) => {
		for (const plot of clone.querySelectorAll('[data-screenshot-plot]')) {
			const image = images[parseInt(plot.dataset.screenshotPlot)]?.image;
			if (!image) continue;
			const img = document.createElement('img');
			img.src = image;
			setStyles(img, { display: 'block', width: '100%', height: '100%' });
			plot.replaceChildren(img);
		}
	};

	// SVG graphs are slow to copy, so draw them as images.
	const svgStyleProperties = [
		'display',
		'visibility',
		'opacity',
		'fill',
		'fill-opacity',
		'fill-rule',
		'stroke',
		'stroke-width',
		'stroke-opacity',
		'stroke-dasharray',
		'stroke-dashoffset',
		'stroke-linecap',
		'stroke-linejoin',
		'font-family',
		'font-size',
		'font-style',
		'font-weight',
		'text-anchor',
		'dominant-baseline'
	];

	const svgToImage = async (svg, rect, scale) => {
		const copy = svg.cloneNode(true);
		const copies = [copy, ...copy.querySelectorAll('*')];
		[svg, ...svg.querySelectorAll('*')].forEach((element, index) => {
			const style = getComputedStyle(element);
			for (const name of svgStyleProperties) {
				const value = style.getPropertyValue(name);
				if (value && !value.includes('url(')) copies[index].style.setProperty(name, value);
			}
		});
		for (const foreignObject of copy.querySelectorAll('foreignObject')) foreignObject.remove();
		copy.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
		copy.setAttribute('width', rect.width.toString());
		copy.setAttribute('height', rect.height.toString());

		const img = new Image();
		img.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(new XMLSerializer().serializeToString(copy))}`;
		await img.decode();
		const canvas = document.createElement('canvas');
		canvas.width = Math.round(rect.width * scale);
		canvas.height = Math.round(rect.height * scale);
		canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
		return canvas.toDataURL();
	};

	const getSvgImages = async (mark, scale) => {
		const svgs = Array.from(problemBody.querySelectorAll('svg')).filter(
			(svg) =>
				!svg.parentElement.closest('svg, mjx-container, .js-plotly-plot') && !svg.querySelector('image, use')
		);
		const images = [];
		for (const svg of svgs) {
			const rect = svg.getBoundingClientRect();
			if (!rect.width || !rect.height) continue;
			const image = await svgToImage(svg, rect, scale).catch(() => null);
			if (!image) continue;
			mark(svg, 'screenshotSvg', images.length.toString());
			images.push({ svg, image, width: rect.width, height: rect.height });
		}
		return images;
	};

	const setSvgImagesInClone = (clone, images) => {
		for (const svg of clone.querySelectorAll('[data-screenshot-svg]')) {
			const { image, width, height } = images[parseInt(svg.dataset.screenshotSvg)] ?? {};
			if (!image) continue;
			svg.removeAttribute('viewBox');
			const svgImage = document.createElementNS('http://www.w3.org/2000/svg', 'image');
			for (const [name, value] of Object.entries({ width, height, href: image, preserveAspectRatio: 'none' }))
				svgImage.setAttribute(name, value.toString());
			svg.replaceChildren(svgImage);
		}
	};

	// Limit the slow redraws that modern-screenshot does for each image in Firefox and Safari.
	const limitImageRedraws = (context, maxRedraws = 3) => {
		let count = context.drawImageCount ?? 0;
		Object.defineProperty(context, 'drawImageCount', {
			get: () => Math.min(count, maxRedraws),
			set: (value) => (count = value)
		});
	};

	let screenshotTaken = false;

	feedbackForm.addEventListener('submit', async (e) => {
		if (screenshotTaken) return;
		e.preventDefault();

		const submitter =
			e.submitter instanceof HTMLButtonElement || e.submitter instanceof HTMLInputElement ? e.submitter : null;
		if (submitter) submitter.disabled = true;

		const { mark, apply: applyMarks, remove: removeMarks } = createMarker();
		let timedOut = false;
		try {
			const dataURL = await Promise.race([
				(async () => {
					const scale = Math.min(Math.max(window.devicePixelRatio || 1, 1), 2);
					const popoverLayout = getPopoverLayout(mark);
					const inputStates = getFormState(mark);
					const { pseudoElements, boxShadowStyles } = scanElements(mark);
					const [pseudoElementStyles, plotImages, svgImages] = await Promise.all([
						getPseudoElementImageStyles(pseudoElements, mark),
						getPlotImages(mark, scale),
						getSvgImages(mark, scale)
					]);
					const replacedElements = new Set([
						...plotImages.map(({ plot }) => plot),
						...svgImages.map(({ svg }) => svg)
					]);
					if (timedOut) return;
					applyMarks();
					const context = await modernScreenshot.createContext(problemBody, {
						autoDestruct: true,
						scale,
						timeout: 10000,
						filter: (node) => !replacedElements.has(node.parentNode),
						...(popoverLayout.numPopovers
							? { width: popoverLayout.width, height: popoverLayout.height }
							: {}),
						onCloneNode: (clone) => {
							setFormStateInClone(clone, inputStates);
							setBoxShadowsInClone(clone, boxShadowStyles);
							setPlotImagesInClone(clone, plotImages);
							setSvgImagesInClone(clone, svgImages);
							if (popoverLayout.numPopovers) layoutPopoversInClone(clone, popoverLayout);
						},
						onCreateForeignObjectSvg: (svg) => {
							const style = document.createElement('style');
							// Prevent MathJax output from being clipped.
							style.textContent = `foreignObject svg { overflow: visible; }\n${pseudoElementStyles}`;
							svg.append(style);
						}
					});
					limitImageRedraws(context);
					return modernScreenshot.domToPng(context);
				})(),
				new Promise((_resolve, reject) =>
					setTimeout(() => {
						timedOut = true;
						reject(new Error('Timed out taking screenshot of problem.'));
					}, 15000)
				)
			]);

			if (dataURL.length * 0.75 <= parseInt(feedbackForm.dataset.screenshotMaxSize))
				screenshotInput.value = dataURL;
		} catch (err) {
			console.error(err);
		} finally {
			removeMarks();
		}

		if (submitter) submitter.disabled = false;
		screenshotTaken = true;
		feedbackForm.requestSubmit(submitter);
		screenshotTaken = false;
	});
})();
