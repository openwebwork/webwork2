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

(function () {
	if (CodeMirror) {
		cm = CodeMirror.fromTextArea(
			document.querySelector('.codeMirrorEditor'), {
				mode: 'PG',
				theme: localStorage.getItem('WW_PGEditor_selected_theme') ?? 'default',
				keyMap: localStorage.getItem('WW_PGEditor_selected_keymap') ?? 'default',
				indentUnit: 4,
				tabMode: 'spaces',
				lineNumbers: true,
				lineWrapping: true,
				extraKeys: { Tab: (cm) => cm.execCommand('insertSoftTab') },
				highlightSelectionMatches: { annotateScrollbar: true },
				matchBrackets: true,
				inputStyle: 'contenteditable',
				spellcheck: localStorage.getItem('WW_PGEditor_spellcheck') === 'true'
			});
		cm.setSize('100%', 400);

		const selectTheme = document.getElementById('selectTheme');
		selectTheme.value = localStorage.getItem('WW_PGEditor_selected_theme') ?? 'default';
		selectTheme.addEventListener('change', () => {
			cm.setOption('theme', selectTheme.value);
			localStorage.setItem('WW_PGEditor_selected_theme', selectTheme.value);
		});

		const selectKeymap = document.getElementById('selectKeymap');
		selectKeymap.value = localStorage.getItem('WW_PGEditor_selected_keymap') ?? 'default';
		selectKeymap.addEventListener('change', () => {
			cm.setOption('keyMap', selectKeymap.value);
			localStorage.setItem('WW_PGEditor_selected_keymap', selectKeymap.value);
		});

		const enableSpell = document.getElementById('enableSpell');
		enableSpell.checked = localStorage.getItem('WW_PGEditor_spellcheck') === 'true';
		enableSpell.addEventListener('change', () => {
			cm.setOption('spellcheck', enableSpell.checked);
			localStorage.setItem('WW_PGEditor_spellcheck', enableSpell.checked);
			cm.focus();
		});
	}
})();
