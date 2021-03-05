"use strict";

(function() {
	function imageViewDialog() {
		var elt = $(this);
		var img = this.cloneNode(true);
		var imgType = img.tagName.toLowerCase();
		img.classList.remove('image-view-elt');
		img.removeAttribute('tabindex');
		img.removeAttribute('role');
		img.removeAttribute('width');
		img.removeAttribute('height');
		img.removeAttribute('style');

		var imgHtml = img.outerHTML;
		if (imgType == 'svg') {
			var ids = imgHtml.match(/\bid="[^"]*"/g);
			if (ids) {
				// Sort the ids from longest to shortest.
				ids.sort(function(a, b) { return b.length - a.length; });
				ids.forEach(function(id) {
					var idString = id.replace(/id="(.*)"/, "$1");
					imgHtml = imgHtml.replaceAll(idString, "viewDialog" + idString);
				});
			}
		}

		var modal = $('<div class="modal image-view-dialog" tabindex="-1" data-keyboard="true" role="dialog" aria-label="image view dialog">' +
			'<div class="modal-header">' +
			'<button type="button" class="btn zoom-in" aria-label="zoom in">' +
			'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-zoom-in" viewBox="0 0 16 16" aria-hidden="true"><path fill-rule="evenodd" d="M6.5 12a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11zM13 6.5a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0z"/><path d="M10.344 11.742c.03.04.062.078.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.1 6.538 6.538 0 0 1-1.398 1.4z"/><path fill-rule="evenodd" d="M6.5 3a.5.5 0 0 1 .5.5V6h2.5a.5.5 0 0 1 0 1H7v2.5a.5.5 0 0 1-1 0V7H3.5a.5.5 0 0 1 0-1H6V3.5a.5.5 0 0 1 .5-.5z"/></svg>' +
			'</button>' +
			'<button type="button" class="btn zoom-out" aria-label="zoom out">' +
			'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-zoom-out" viewBox="0 0 16 16" aria-hidden="true"><path fill-rule="evenodd" d="M6.5 12a5.5 5.5 0 1 0 0-11 5.5 5.5 0 0 0 0 11zM13 6.5a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0z"/><path d="M10.344 11.742c.03.04.062.078.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.1 6.538 6.538 0 0 1-1.398 1.4z"/><path fill-rule="evenodd" d="M3 6.5a.5.5 0 0 1 .5-.5h6a.5.5 0 0 1 0 1h-6a.5.5 0 0 1-.5-.5z"/></svg>' +
			'</button>' +
			'<span class="drag-handle">&nbsp;</span>' +
			'<button type="button" class="close" data-dismiss="modal" aria-label="close">' +
			'<span aria-hidden="true">&times;</span>' +
			'</button>' +
			'</div>' +
			'<div class="modal-body">' + imgHtml + '</div>' +
			'</div>'
		);
		modal.css('margin', '0px');

		var body = modal.find('.modal-body');
		var header = modal.find('.modal-header');
		var dragHandle = header.find('.drag-handle');
		var zoomIn = header.find('.zoom-in');
		var zoomOut = header.find('.zoom-out');

		modal.on('shown', function () {
			// Find the natural dimensions of the image.
			var naturalWidth, naturalHeight;
			if (imgType == 'img') {
				naturalWidth = elt.prop('naturalWidth');
				naturalHeight = elt.prop('naturalHeight');
			} else if (imgType == 'svg') {
				var svg = modal.find('.modal-body svg');
				var viewBoxDims = svg.prop('viewBox').baseVal;
				// This assumes the units of the view box dimensions are points.
				naturalWidth = viewBoxDims.width * 4 / 3;
				naturalHeight = viewBoxDims.height * 4 / 3;
			}

			var headerHeight = header.outerHeight();

			// Initial image maximum width and height
			var maxWidth = window.innerWidth - 18;
			var maxHeight = window.innerHeight - headerHeight - 18;

			// Dialog maximum width and height
			modal.css({
				'max-width': maxWidth + 16,
				'max-height': maxHeight + headerHeight + 16
			});

			// Initial image width and height.
			var width = naturalWidth;
			var height = naturalHeight;

			// Dialog position
			var left;
			var top;

			function repositionModal(x, y) {
				if (x < 0 || width >= maxWidth) left = 0;
				else if (x + width > maxWidth) left = maxWidth - width;
				else left = x;
				if (y < 0 || height >= maxHeight) top = 0;
				else if (y + height > maxHeight) top = maxHeight - height;
				else top = y;

				modal.css({ 'left': left + 'px', 'top': top + 'px' });
			}

			// Resize the modal.  Care is taken to maintain the aspect ratio.
			function zoom(factor, initial) {
				// Save the current dimensions for repositioning later.
				var initialWidth = width;
				var initialHeight = height;

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
				body.css({ width: width + "px", height: height + "px" });
				modal.css({ width: (width + 16) + "px", height: (height + headerHeight + 16) + "px" });

				// Re-position the modal.
				if (initial) {
					// Center the modal initially
					repositionModal((maxWidth - width) / 2, (maxHeight - height) / 2);
				} else {
					repositionModal(left - (width - initialWidth) / 2, top - (height - initialHeight) / 2);
				}

				modal.focus();
			};

			// Make the dialog draggable
			dragHandle.on('pointerdown', function(e) {
				e.preventDefault();

				// Save the position of the pointer event relative to the top left corner of the dialog.
				var pointerPosX = e.originalEvent.offsetX + dragHandle[0].offsetLeft;
				var pointerPosY = e.originalEvent.offsetY + dragHandle[0].offsetTop;

				dragHandle.on('pointermove.ImageViewDrag', function(e) {
					e.preventDefault();
					repositionModal(e.originalEvent.clientX - pointerPosX, e.originalEvent.clientY - pointerPosY);
				});
				dragHandle[0].setPointerCapture(e.originalEvent.pointerId);
			});

			dragHandle.on('lostpointercapture', function(e) {
				e.preventDefault();
				dragHandle.off('pointermove.ImageViewDrag');
			});

			// Set up the zoom in and zoom out click handlers.
			zoomIn.click(function(e) { this.blur(); zoom(1.25); });
			zoomOut.click(function(e) { this.blur(); zoom(0.8); });

			$(window).on('resize.ImageView', function(e) {
				maxWidth = window.innerWidth - 18;
				maxHeight = window.innerHeight - headerHeight - 18;
				modal.css({ 'max-width': maxWidth + 16, 'max-height': maxHeight + headerHeight + 16 });
				zoom(1);
			});

			// The + or = key zooms in and the - key zooms out.
			modal.on('keydown', function(e) {
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
			modal.on('wheel', function(e) {
				e.preventDefault();
				if (e.originalEvent.deltaY < 0) zoom(1.25);
				if (e.originalEvent.deltaY > 0) zoom(0.8);
			});

			// Perform the initial zoom
			zoom(1, true);

			// Make the backdrop a little lighter
			$('.modal-backdrop').css('opacity', '0.2');
		});
		modal.on('hidden', function() {
			modal.remove();
			$(window).off("resize.ImageView");
			elt.focus();
		})
		modal.modal('show');
	}

	function keyHandler(e) {
		if (e.key === ' ' || e.key === 'Enter') {
			e.preventDefault();
			imageViewDialog.call(this);
		}
	}

	$(function() {
		// Set up images that are already in the page.
		$('.image-view-elt').on('click.ImageView', imageViewDialog).on('keydown.ImageView', keyHandler);

		// Deal with images that are added to the page later.
		var observer = new MutationObserver(function(mutationsList, observer) {
			mutationsList.forEach(function(mutation) {
				$(mutation.addedNodes).each(function() {
					if (this.classList && this.classList.contains('image-view-elt')) {
						$(this).off('click.ImageView').on('click.ImageView', imageViewDialog)
							.off('keydown.ImageView').on('keydown.ImageView', keyHandler);
					} else {
						$(this).find('.image-view-elt')
							.off('click.ImageView').on('click.ImageView', imageViewDialog)
							.off('keydown.ImageView').on('keydown.ImageView', keyHandler);
					}
				});
			});
		});
		observer.observe($('body')[0], { childList: true, subtree: true });

		// Stop the mutation observer when the window is closed.
		window.addEventListener('unload', function() { observer.disconnect(); });
	});
})();
