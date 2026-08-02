(() => {
	// Enable site-navigation menu toggling if the page has a site-navigation element.
	const navigation_element = document.getElementById('site-navigation');
	if (navigation_element) {
		const threshold = 768;
		let currentWidth = window.innerWidth;
		const content = document.getElementById('content');
		const masthead = document.querySelector('.masthead');
		const toggleButton = document.getElementById('toggle-sidebar');
		const skipLink = document.getElementById('skip-to-main-content');

		// Make masthead, content, and skip to main content link inert while the drawer is open.
		let sidebarBackdrop = null;

		const handleEscapeKey = (e) => {
			if (e.key !== 'Escape') return;
			navigation_element.classList.remove('toggle-width');
			content.classList.remove('toggle-width');
			closeNarrowScreenDrawer();
			toggleButton?.focus();
		};

		const closeNarrowScreenDrawer = () => {
			if (!sidebarBackdrop) return;
			sidebarBackdrop.remove();
			sidebarBackdrop = null;
			document.body.classList.remove('no-scroll');
			content.inert = false;
			if (masthead) masthead.inert = false;
			if (skipLink) skipLink.inert = false;
			document.removeEventListener('keydown', handleEscapeKey);
		};

		const openNarrowScreenDrawer = () => {
			content.inert = true;
			if (masthead) masthead.inert = true;
			if (skipLink) skipLink.inert = true;
			document.body.classList.add('no-scroll');
			document.addEventListener('keydown', handleEscapeKey);

			sidebarBackdrop = document.createElement('div');
			sidebarBackdrop.classList.add('sidebar-backdrop');
			document.body.append(sidebarBackdrop);
			sidebarBackdrop.addEventListener('click', () => {
				navigation_element.classList.remove('toggle-width');
				content.classList.remove('toggle-width');
				closeNarrowScreenDrawer();
				toggleButton?.focus();
			});
		};

		const toggleSidebar = () => {
			navigation_element.classList.toggle('toggle-width');
			navigation_element.classList.remove('invisible');
			content.classList.toggle('toggle-width');

			if (currentWidth <= threshold) {
				if (sidebarBackdrop) closeNarrowScreenDrawer();
				else openNarrowScreenDrawer();
			}
		};

		toggleButton?.addEventListener('click', toggleSidebar);

		if (currentWidth <= threshold) navigation_element.classList.add('invisible');

		navigation_element.addEventListener('transitionend', () => {
			if (
				(window.innerWidth > threshold && navigation_element.classList.contains('toggle-width')) ||
				(window.innerWidth <= threshold && !navigation_element.classList.contains('toggle-width'))
			)
				navigation_element.classList.add('invisible');
		});

		// If the window width changes open or close the sidebar appropriately.
		window.addEventListener('resize', () => {
			if (!navigation_element.classList.contains('toggle-width') && window.innerWidth > threshold)
				navigation_element.classList.remove('invisible');

			if (
				(navigation_element.classList.contains('toggle-width') &&
					window.innerWidth <= threshold &&
					currentWidth > threshold) ||
				(navigation_element.classList.contains('toggle-width') &&
					window.innerWidth > threshold &&
					currentWidth <= threshold)
			) {
				currentWidth = window.innerWidth;
				toggleSidebar();
				closeNarrowScreenDrawer();
			}
			currentWidth = window.innerWidth;
		});
	}

	// Make elements with role="button" (that have been given the class below) activate upon use of the spacebar.
	for (const btn of document.querySelectorAll('.spacebar-activatable')) {
		btn.addEventListener('keydown', (e) => {
			if (e.key === ' ') {
				e.preventDefault();
				btn.click();
			}
		});
	}

	// Turn help boxes into popovers
	document.querySelectorAll('.help-popup').forEach((popover) => {
		popover.addEventListener('click', (e) => e.preventDefault());
		new bootstrap.Popover(popover, { trigger: 'hover focus' });
	});

	// Problem page popovers
	document
		.querySelectorAll('.student-nav-button')
		.forEach((el) => new bootstrap.Tooltip(el, { trigger: 'hover', fallbackPlacements: [] }));

	// Homework sets editor config
	// FIXME: These are really general purpose tooltips and not just in the homework sets editor.  So the class name
	// should be chosen to better reflect this.
	document.querySelectorAll('.set-id-tooltip').forEach((el) => {
		if (el.dataset.bsTitle)
			new bootstrap.Tooltip(el, { fallbackPlacements: el.dataset.fallbackPlacements?.split(' ') || [] });
	});

	// Hardcopy tooltips shown on the Problem Sets page.
	document
		.querySelectorAll('.hardcopy-tooltip')
		.forEach((el) => new bootstrap.Tooltip(el, { trigger: 'hover', fallbackPlacements: [], html: true }));

	const messages = document.querySelectorAll('#message .alert-dismissible, #message_bottom .alert-dismissible');
	if (messages.length) {
		const dismissBtn = document.getElementById('dismiss-messages-btn');
		dismissBtn?.classList.remove('d-none');

		// Hide the dismiss button when the last alert is dismissed.
		for (const message of messages) {
			message.addEventListener(
				'closed.bs.alert',
				() => {
					if (!document.querySelector('#message .alert-dismissible, #message_bottom .alert-dismissible'))
						dismissBtn.remove();
				},
				{ once: true }
			);
		}

		dismissBtn?.addEventListener('click', () =>
			messages.forEach((message) => bootstrap.Alert.getOrCreateInstance(message)?.close())
		);
	}
})();
