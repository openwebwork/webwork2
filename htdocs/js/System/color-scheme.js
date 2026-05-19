'use strict';

(() => {
	const getPreferredTheme = () => {
		const storedTheme = localStorage.getItem('WW.color-scheme');
		if (storedTheme) return storedTheme;
		return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
	};

	let flatpickrDarkTheme;

	const setTheme = (theme) => {
		const themeValue =
			theme === 'auto' ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : theme;
		document.documentElement.setAttribute('data-bs-theme', themeValue);

		if (!flatpickrDarkTheme) flatpickrDarkTheme = document.getElementById('flatpickr-dark-theme');
		if (flatpickrDarkTheme) {
			if (themeValue === 'dark') document.head.append(flatpickrDarkTheme);
			else flatpickrDarkTheme.remove();
		}
	};

	setTheme(getPreferredTheme());

	const showActiveTheme = (theme, focus = false) => {
		const themeSwitcher = document.getElementById('color-scheme-chooser');
		if (!themeSwitcher) return;

		const activeThemeIcon = themeSwitcher.querySelector('.theme-icon-active');
		const btnToActive = document.querySelector(`[data-bs-theme-value="${theme}"]`);

		for (const element of document.querySelectorAll('[data-bs-theme-value]')) {
			element.classList.remove('active');
			element.setAttribute('aria-pressed', 'false');
		}

		btnToActive.classList.add('active');
		btnToActive.setAttribute('aria-pressed', 'true');
		activeThemeIcon.classList.remove('fa-sun', 'fa-moon', 'fa-circle-half-stroke');
		activeThemeIcon.classList.add(
			theme === 'light' ? 'fa-sun' : theme === 'dark' ? 'fa-moon' : 'fa-circle-half-stroke'
		);
		themeSwitcher.setAttribute(
			'aria-label',
			`${themeSwitcher.title} (${
				themeSwitcher.dataset[`${btnToActive.dataset.bsThemeValue}Text`] ?? btnToActive.dataset.bsThemeValue
			})`
		);

		if (focus) themeSwitcher.focus();
	};

	window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
		const storedTheme = localStorage.getItem('WW.color-scheme');
		if (storedTheme !== 'light' && storedTheme !== 'dark') {
			const preferredTheme = getPreferredTheme();
			setTheme(preferredTheme);
			showActiveTheme(preferredTheme);
		}
	});

	window.addEventListener('DOMContentLoaded', () => {
		showActiveTheme(getPreferredTheme());

		for (const toggle of document.querySelectorAll('[data-bs-theme-value]')) {
			toggle.addEventListener('click', () => {
				const theme = toggle.getAttribute('data-bs-theme-value');
				localStorage.setItem('WW.color-scheme', theme);
				setTheme(theme);
				showActiveTheme(theme, true);
			});
		}
	});
})();
