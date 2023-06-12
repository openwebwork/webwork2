/* WeBWorK Online Homework Delivery System
 * Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

(async function () {
	if (!CodeMirror) return;

	const loadResource = async (src) => {
		return new Promise((resolve, reject) => {
			let shouldAppend = false;
			let el;
			if (/\.js(?:\?[0-9a-zA-Z=^.]*)?$/.exec(src)) {
				el = document.querySelector(`script[src="${src}"]`);
				if (!el) {
					el = document.createElement('script');
					el.async = false;
					el.src = src;
					shouldAppend = true;
				}
			} else if (/\.css(?:\?[0-9a-zA-Z=^.]*)?$/.exec(src)) {
				el = document.querySelector(`link[href="${src}"]`);
				if (!el) {
					el = document.createElement('link');
					el.rel = 'stylesheet';
					el.href = src;
					shouldAppend = true;
				}
			} else {
				reject();
				return;
			}

			if (el.dataset.loaded) {
				resolve();
				return;
			}

			el.addEventListener('error', reject);
			el.addEventListener('abort', reject);
			el.addEventListener('load', () => {
				if (el) el.dataset.loaded = 'true';
				resolve();
			});

			if (shouldAppend) document.head.appendChild(el);
		});
	};

	const loadConfig = async (file) => {
		const configName = [...file.matchAll(/.*\/([^.]*?)(?:\.min)?\.(?:js|css)(?:\?[0-9a-zA-Z=^.]*)?$/g)][0]?.[1]
			?? 'default';
		if (configName !== 'default') {
			try {
				await loadResource(file);
			} catch {
				return 'default';
			}
		}
		return configName;
	};

	const cm = webworkConfig.pgCodeMirror = CodeMirror.fromTextArea(document.querySelector('.codeMirrorEditor'), {
		mode: document.querySelector('.codeMirrorEditor')?.dataset.mode ?? 'PG',
		indentUnit: 4,
		tabMode: 'spaces',
		lineNumbers: true,
		lineWrapping: true,
		extraKeys: { Tab: (cm) => cm.execCommand('insertSoftTab') },
		highlightSelectionMatches: { annotateScrollbar: true },
		matchBrackets: true,
		inputStyle: 'contenteditable',
		spellcheck: localStorage.getItem('WW_PGEditor_spellcheck') === 'true',
	});
	cm.setSize('100%', '550px');

	const currentThemeFile = localStorage.getItem('WW_PGEditor_selected_theme') ?? 'default';
	const currentThemeName = await loadConfig(currentThemeFile);
	cm.setOption('theme', currentThemeName);

	const currentKeymapFile = localStorage.getItem('WW_PGEditor_selected_keymap') ?? 'default';
	const currentKeymapName = await loadConfig(currentKeymapFile);
	cm.setOption('keyMap', currentKeymapName);

	const selectTheme = document.getElementById('selectTheme');
	selectTheme.value = currentThemeName === 'default' ? 'default' : currentThemeFile;
	selectTheme.addEventListener('change', async () => {
		const themeName = await loadConfig(selectTheme.value);
		cm.setOption('theme', themeName);
		localStorage.setItem('WW_PGEditor_selected_theme', themeName === 'default' ? 'default' : selectTheme.value);
	});

	const selectKeymap = document.getElementById('selectKeymap');
	selectKeymap.value = currentKeymapName === 'default' ? 'default' : currentKeymapFile;
	selectKeymap.addEventListener('change', async () => {
		const keymapName = await loadConfig(selectKeymap.value);
		cm.setOption('keyMap', keymapName);
		localStorage.setItem('WW_PGEditor_selected_keymap',
			keymapName === 'default' ? 'default' : selectKeymap.value);
	});

	const enableSpell = document.getElementById('enableSpell');
	enableSpell.checked = localStorage.getItem('WW_PGEditor_spellcheck') === 'true';
	enableSpell.addEventListener('change', () => {
		cm.setOption('spellcheck', enableSpell.checked);
		localStorage.setItem('WW_PGEditor_spellcheck', enableSpell.checked);
		cm.focus();
	});

	const forceRTL = document.getElementById('forceRTL');
	forceRTL.addEventListener('change', () => {
		cm.setOption('direction', forceRTL.checked ? 'rtl' : 'ltr');
	});
})();
