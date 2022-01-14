'use strict';

/* global bootstrap */

(() => {
	const imageViewDialog = function() {
		const img = this.cloneNode(true);
		const imgType = img.tagName.toLowerCase();
		img.classList.remove('image-view-elt');
		img.removeAttribute('tabindex');
		img.removeAttribute('role');
		img.removeAttribute('width');
		img.removeAttribute('height');
		img.removeAttribute('style');

		let imgHtml = img.outerHTML;
		if (imgType == 'svg') {
			const ids = imgHtml.match(/\bid="[^"]*"/g);
			if (ids) {
				// Sort the ids from longest to shortest.
				ids.sort((a, b) => b.length - a.length);
				ids.forEach((id) => {
					const idString = id.replace(/id="(.*)"/, '$1');
					imgHtml = imgHtml.replaceAll(idString, 'viewDialog' + idString);
				});
			}
		}

		const modal = document.createElement('div');
		modal.classList.add('modal', 'image-view-dialog');
		modal.ariaLabel = 'image view dialog';
		modal.tabIndex = -1;

		const dialog = document.createElement('div');
		dialog.classList.add('modal-dialog');

		const content = document.createElement('div');
		content.classList.add('modal-content');

		const header = document.createElement('div');
		header.classList.add('modal-header');

		const zoomInButton = document.createElement('button');
		zoomInButton.type = 'button';
		zoomInButton.classList.add('btn', 'zoom-in');
		zoomInButton.ariaLabel = 'zoom in';

		const zoomInSVG = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
		zoomInSVG.classList.add('bi', 'bi-zoom-in');
		zoomInSVG.setAttribute('width', 16);
		zoomInSVG.setAttribute('height', 16);
		zoomInSVG.setAttribute('fill', 'currentColor');
		zoomInSVG.setAttribute('viewBox', '0 0 16 16');
		zoomInSVG.setAttribute('aria-hidden', true);
		const zoomInPath1 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		zoomInPath1.setAttribute('fill-rule', 'evenodd');
		zoomInPath1.setAttribute('d',
			'M6.5 12a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11zM13 6.5a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0z');
		const zoomInPath2 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		zoomInPath2.setAttribute('d',
			'M10.344 11.742c.03.04.062.078.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 ' +
			'1.007 0 0 0-.115-.1 6.538 6.538 0 0 1-1.398 1.4z');
		const zoomInPath3 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		zoomInPath3.setAttribute('fill-rule', 'evenodd');
		zoomInPath3.setAttribute('d',
			'M6.5 3a.5.5 0 0 1 .5.5V6h2.5a.5.5 0 0 1 0 1H7v2.5a.5.5 0 0 1-1 0V7H3.5a.5.5 0 0 1 ' +
			'0-1H6V3.5a.5.5 0 0 1 .5-.5z');
		zoomInSVG.append(zoomInPath1, zoomInPath2, zoomInPath3);

		const zoomOutButton = document.createElement('button');
		zoomOutButton.type = 'button';
		zoomOutButton.classList.add('btn', 'zoom-in');
		zoomOutButton.ariaLabel = 'zoom in';

		const zoomOutSVG = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
		zoomOutSVG.classList.add('bi', 'bi-zoom-out');
		zoomOutSVG.setAttribute('width', 16);
		zoomOutSVG.setAttribute('height', 16);
		zoomOutSVG.setAttribute('fill', 'currentColor');
		zoomOutSVG.setAttribute('viewBox', '0 0 16 16');
		zoomOutSVG.setAttribute('aria-hidden', true);
		const zoomOutPath1 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		zoomOutPath1.setAttribute('fill-rule', 'evenodd');
		zoomOutPath1.setAttribute('d',
			'M6.5 12a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11zM13 6.5a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0z');
		const zoomOutPath2 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		zoomOutPath2.setAttribute('d',
			'M10.344 11.742c.03.04.062.078.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 ' +
			'0 0 0-.115-.1 6.538 6.538 0 0 1-1.398 1.4z');
		const zoomOutPath3 = document.createElementNS('http://www.w3.org/2000/svg', 'path');
		zoomOutPath3.setAttribute('fill-rule', 'evenodd');
		zoomOutPath3.setAttribute('d',
			'M3 6.5a.5.5 0 0 1 .5-.5h6a.5.5 0 0 1 0 1h-6a.5.5 0 0 1-.5-.5z');
		zoomOutSVG.append(zoomOutPath1, zoomOutPath2, zoomOutPath3);

		const dragHandle = document.createElement('span');
		dragHandle.classList.add('drag-handle');
		dragHandle.textContent = '\u00A0';

		const closeButton = document.createElement('button');
		closeButton.type = 'button';
		closeButton.classList.add('btn-close');
		closeButton.dataset.bsDismiss = 'modal';
		closeButton.ariaLabel = 'close';

		const body = document.createElement('div');
		body.classList.add('modal-body');
		body.innerHTML = imgHtml;

		zoomInButton.append(zoomInSVG);
		zoomOutButton.append(zoomOutSVG);
		header.append(zoomInButton, zoomOutButton, dragHandle, closeButton);
		content.append(header, body);
		dialog.append(content);
		modal.append(dialog);

		let onWinResize;

		modal.addEventListener('shown.bs.modal', () => {
			// Find the natural dimensions of the image.
			let naturalWidth, naturalHeight;
			if (imgType == 'img') {
				naturalWidth = this.naturalWidth;
				naturalHeight = this.naturalHeight;
			} else if (imgType == 'svg') {
				const svg = body.querySelector('svg');
				const viewBoxDims = svg.viewBox.baseVal;
				// This assumes the units of the view box dimensions are points.
				naturalWidth = viewBoxDims.width * 4 / 3;
				naturalHeight = viewBoxDims.height * 4 / 3;
			}

			const headerHeight = header.offsetHeight;

			// Initial image maximum width and height
			let maxWidth = window.innerWidth - 18;
			let maxHeight = window.innerHeight - headerHeight - 18;

			// Dialog maximum width and height
			dialog.style.maxWidth = (maxWidth + 18) + 'px';
			dialog.style.maxHeight = (maxHeight + headerHeight + 18) + 'px';

			// Initial image width and height
			let width = naturalWidth;
			let height = naturalHeight;

			// Dialog position
			let left;
			let top;

			const repositionModal = (x, y) => {
				if (x < 0 || width >= maxWidth) left = 0;
				else if (x + width > maxWidth) left = maxWidth - width;
				else left = x;
				if (y < 0 || height >= maxHeight) top = 0;
				else if (y + height > maxHeight) top = maxHeight - height;
				else top = y;

				dialog.style.left = left + 'px';
				dialog.style.top = top + 'px';
			};

			// Resize the modal.  Care is taken to maintain the aspect ratio.
			const zoom = (factor, initial) => {
				// Save the current dimensions for repositioning later.
				const initialWidth = width;
				const initialHeight = height;

				// Determine the width and height after applying the zoom factor.
				if (factor * width > maxWidth || factor * height > maxHeight) {
					width = maxWidth;
					height = width * naturalHeight / naturalWidth;
					if (height > maxHeight) {
						height = maxHeight;
						width = height * naturalWidth / naturalHeight;
					}
				} else if (factor * width < 100 || factor * height < 100) {
					width = 100;
					height = width * naturalHeight / naturalWidth;
					if (height < 100) {
						height = 100;
						width = height * naturalWidth / naturalHeight;
					}
				} else {
					width = factor * width;
					height = factor * height;
				}

				// Resize the modal
				body.style.width = width + 'px';
				body.style.height = height + 'px';
				dialog.style.width = (width + 18) + 'px';
				dialog.style.height = (height + headerHeight + 18) + 'px';

				// Re-position the modal.
				if (initial) {
					// Center the modal initially
					repositionModal((maxWidth - width) / 2, (maxHeight - height) / 2);
				} else {
					repositionModal(left - (width - initialWidth) / 2, top - (height - initialHeight) / 2);
				}

				dialog.focus();
			};

			// Make the dialog draggable
			dragHandle.addEventListener('pointerdown', (e) => {
				e.preventDefault();

				// Save the position of the pointer event relative to the top left corner of the dialog.
				const pointerPosX = e.offsetX + dragHandle.offsetLeft;
				const pointerPosY = e.offsetY + dragHandle.offsetTop;

				const imageViewDrag = (e) => {
					e.preventDefault();
					repositionModal(e.clientX - pointerPosX, e.clientY - pointerPosY);
				};

				dragHandle.addEventListener('pointermove', imageViewDrag);
				dragHandle.setPointerCapture(e.pointerId);
				dragHandle.addEventListener('lostpointercapture', (e) => {
					e.preventDefault();
					dragHandle.removeEventListener('pointermove', imageViewDrag);
				}, { once: true });

			});

			// Set up the zoom in and zoom out click handlers.
			zoomInButton.addEventListener('click', () => { zoomInButton.blur(); zoom(1.25); });
			zoomOutButton.addEventListener('click', () => { zoomOutButton.blur(); zoom(0.8); });

			onWinResize = () => {
				maxWidth = window.innerWidth - 18;
				maxHeight = window.innerHeight - headerHeight - 18;
				dialog.style.maxWidth = (maxWidth + 18) + 'px';
				dialog.style.maxHeight = (maxHeight + headerHeight + 18) + 'px';

				// Update the dialog position and size
				zoom(1);
			};

			window.addEventListener('resize', onWinResize);

			// The + or = key zooms in and the - key zooms out.
			modal.addEventListener('keydown', (e) => {
				if (e.key === '=' || e.key === '+') zoom(1.25);
				if (e.key === '-') zoom(0.8);

				// ctrl+0 resets to the natural width and height
				if (e.ctrlKey && e.key === '0') {
					width = naturalWidth;
					height = naturalHeight;
					zoom(1);
				}
			});

			// The mouse wheel zooms in and out also.
			dialog.addEventListener('wheel', (e) => {
				e.preventDefault();
				if (e.deltaY < 0) zoom(1.25);
				if (e.deltaY > 0) zoom(0.8);
			});

			// Perform the initial zoom
			zoom(1, true);

			// Make the backdrop a little lighter and set the size
			const backdrop = document.querySelector('.modal-backdrop');
			backdrop.style.opacity = '0.2';
		});
		modal.addEventListener('hidden.bs.modal', () => {
			bsModal.dispose();
			modal.remove();
			window.removeEventListener('resize', onWinResize);
			this.focus();
		});
		const bsModal = new bootstrap.Modal(modal);
		bsModal.show();
	};

	const keyHandler = function(e) {
		if (e.key === ' ' || e.key === 'Enter') {
			e.preventDefault();
			imageViewDialog.call(this);
		}
	};

	// Set up images that are already in the page.
	document.querySelectorAll('.image-view-elt').forEach((elt) => {
		elt.addEventListener('click', imageViewDialog);
		elt.addEventListener('keydown', keyHandler);
	});

	const attachListeners = (node) => {
		node.removeEventListener('click', imageViewDialog);
		node.removeEventListener('keydown', keyHandler);
		node.addEventListener('click', imageViewDialog);
		node.addEventListener('keydown', keyHandler);
	};

	// Deal with images that are added to the page later.
	const observer = new MutationObserver((mutationsList) => {
		mutationsList.forEach((mutation) => {
			mutation.addedNodes.forEach((node) => {
				if (node instanceof Element) {
					if (node.classList.contains('image-view-elt')) attachListeners(node);
					else node.querySelectorAll('.image-view-elt').forEach(attachListeners);
				}
			});
		});
	});
	observer.observe(document.body, { childList: true, subtree: true });

	// Stop the mutation observer when the window is closed.
	window.addEventListener('unload', () => observer.disconnect());
})();
