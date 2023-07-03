/* WeBWorK Online Homework Delivery System
 * Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of either: (a) the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any later
 * version, or (b) the "Artistic License" which comes with this package.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
 * Artistic License for more details.
 */

(() => {
	// Enable site-navigation menu toggling if the page has a site-navigation element.
	const navigation_element = document.getElementById('site-navigation');
	if (navigation_element) {
		const threshold = 768
		let currentWidth = window.innerWidth;
		const content = document.getElementById('content');

		const toggleSidebar = () => {
			navigation_element.classList.toggle('toggle-width');
			navigation_element.classList.remove('invisible');
			content.classList.toggle('toggle-width');

			if (currentWidth < threshold) {
				const overlay = document.createElement('div');
				overlay.classList.add('sidebar-backdrop');
				document.body.append(overlay);
				overlay.addEventListener('click', () => {
					overlay.remove();
					navigation_element.classList.toggle('toggle-width');
					content.classList.toggle('toggle-width');
					document.body.classList.remove('no-scroll');
				});
				document.body.classList.add('no-scroll');
			}
		};

		document.getElementById('toggle-sidebar')?.addEventListener('click', toggleSidebar);

		if (currentWidth < threshold) navigation_element.classList.add('invisible');

		navigation_element.addEventListener('transitionend', () => {
			if (
				(window.innerWidth >= threshold && navigation_element.classList.contains('toggle-width')) ||
				(window.innerWidth < threshold && !navigation_element.classList.contains('toggle-width'))
			)
				navigation_element.classList.add('invisible');
		});

		// If the window width changes open or close the sidebar appropriately.
		window.addEventListener('resize', () => {
			if (!navigation_element.classList.contains('toggle-width') && window.innerWidth >= threshold)
				navigation_element.classList.remove('invisible');

			if ((navigation_element.classList.contains('toggle-width') &&
				window.innerWidth < threshold && currentWidth >= threshold) ||
				(navigation_element.classList.contains('toggle-width') &&
					window.innerWidth >= threshold && currentWidth < threshold))
			{
				currentWidth = window.innerWidth;
				toggleSidebar();
				document.body.classList.remove('no-scroll');
				document.querySelectorAll('.sidebar-backdrop').forEach(overlay => overlay.remove());
			}
			currentWidth = window.innerWidth;
		});
	}

	// Turn help boxes into popovers
	document.querySelectorAll('.help-popup').forEach((popover) => {
		new bootstrap.Popover(popover, {trigger: 'hover focus'});
	});

	// Problem page popovers
	document.querySelectorAll('.student-nav-button').forEach(
		(el) => new bootstrap.Tooltip(el, {trigger: 'hover', fallbackPlacements: []})
	);

	// Set up popovers in the attemptResults table.
	document.querySelectorAll('table.attemptResults td div.answer-preview').forEach((popover) => {
		if (popover.dataset.bsContent) new bootstrap.Popover(popover, {trigger: 'click', html: true, sanitize: false});
	});

	// Sets up problems to rescale the image accoring to attr height width and not native height width.
	const rescaleImage = (_index, element) => {
		if (element.height != element.naturalHeight || element.width != element.naturalWidth) {
			element.height = element.getBoundingClientRect().width * element.height / element.width;
		}
	}
	document.querySelectorAll('.problem-content img').forEach(rescaleImage);
	window.addEventListener('resize', () => document.querySelectorAll('.problem-content img').forEach(rescaleImage));

	// Homework sets editor config
	// FIXME: These are really general purpose tooltips and not just in the homework sets editor.  So the class name
	// should be chosen to better reflect this.
	document.querySelectorAll('.set-id-tooltip').forEach(
		(el) => {if (el.dataset.bsTitle) new bootstrap.Tooltip(el, {trigger: 'hover', fallbackPlacements: []});}
	);

	// Hardcopy tooltips shown on the Problem Sets page.
	document.querySelectorAll('.hardcopy-tooltip').forEach(
		(el) => new bootstrap.Tooltip(el, { trigger: 'hover', fallbackPlacements: [], html: true })
	);

	// PG Problem Editor
	document.querySelectorAll('.reference-link').forEach((el) => new bootstrap.Tooltip(el));

	// SendMail insertable macro toast
	document.getElementById('insertable-macros-btn')?.addEventListener('click', () => {
		new bootstrap.Toast(document.getElementById('insertable-macros'), { autohide: false }).show();
	});

	// For accessibility we need to change single answer aria labels to "answer" and not "answer 1"
	// FIXME: The correct aria-label should be inserted by PG to begin with.  This hack will not work if there is more
	// than one problem on the page.
	const codeshards = document.querySelectorAll('.codeshard');
	if (codeshards.length == 1) codeshards[0].setAttribute('aria-label', 'answer');

	const messages = document.querySelectorAll('#message .alert-dismissible, #message_bottom .alert-dismissible');
	if (messages.length) {
		const dismissBtn = document.getElementById('dismiss-messages-btn');
		dismissBtn?.classList.remove('d-none');

		// Hide the dismiss button when the last alert is dismissed.
		for (const message of messages) {
			message.addEventListener('closed.bs.alert', () => {
				if (!document.querySelector('#message .alert-dismissible, #message_bottom .alert-dismissible'))
					dismissBtn.remove();
			}, { once: true });
		}

		dismissBtn?.addEventListener('click', () =>
			messages.forEach((message) => bootstrap.Alert.getOrCreateInstance(message)?.close())
		);
	}

	// Accessibility
	// Present the contents of the data-alt attribute as alternative content for screen reader users.
	// The icon should be formatted as <i class="icon fas fa-close" data-alt="close"></i>
	// FIXME:  Don't add these by javascript.  Make a content generator method that adds these instead.
	document.querySelectorAll('i.icon').forEach((icon) => {
		if (typeof icon.dataset.alt !== 'undefined') {
			const glyph = document.createElement('span');
			glyph.classList.add('sr-only-glyphicon');
			glyph.style.fontSize = icon.style.fontSize;
			glyph.textContent = icon.dataset.alt;
			icon.after(glyph);
		}
	});
})();
