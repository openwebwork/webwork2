if (MathJax.loader) MathJax.loader.checkVersion('[bs-color-scheme]', '4.1.3', 'extension');

const switchToBSStyle = (obj, key = '@media (prefers-color-scheme: dark)') => {
	obj["[data-bs-theme='dark']"] = obj[key];
	delete obj[key];
	obj["[data-bs-theme='light']"] = structuredClone(obj);
};

for (const [immediate, extension, ready] of [
	[
		MathJax._.ui?.dialog,
		'core',
		() => {
			const { DraggableDialog } = MathJax._.ui.dialog.DraggableDialog;
			switchToBSStyle(DraggableDialog.styles);
		}
	],
	[
		MathJax._.a11y?.explorer,
		'a11y/explorer',
		() => {
			const Region = MathJax._.a11y.explorer.Region;
			for (const region of ['LiveRegion', 'HoverRegion', 'ToolTip']) {
				if (':root' in Region[region].style.styles) {
					Region[region].style.styles["[data-bs-theme='light']"] = Region[region].style.styles[':root'];
				}
				Region[region].style.styles["[data-bs-theme='dark']"] =
					Region[region].style.styles['@media (prefers-color-scheme: dark)'];
				if (':root' in Region[region].style.styles["[data-bs-theme='dark']"]) {
					Object.assign(
						Region[region].style.styles["[data-bs-theme='dark']"],
						Region[region].style.styles["[data-bs-theme='dark']"][':root']
					);
					delete Region[region].style.styles["[data-bs-theme='dark']"][':root'];
				}
				Region[region].style.styles['@media (prefers-color-scheme: dark)'] = {};
			}
			Region.LiveRegion.style.styles['@media (prefers-color-scheme: dark)']['mjx-ignore'] = { ignore: 1 };
			MathJax.startup.extendHandler((handler) => {
				switchToBSStyle(
					handler.documentClass.speechStyles,
					'@media (prefers-color-scheme: dark) /* explorer */'
				);
				return handler;
			});
		}
	],
	[
		MathJax._.output?.chtml,
		'output/chtml',
		() => {
			const { CHTML } = MathJax._.output.chtml_ts;
			switchToBSStyle(CHTML.commonStyles);
			const { ChtmlMaction } = MathJax._.output.chtml.Wrappers.maction;
			switchToBSStyle(ChtmlMaction.styles, '@media (prefers-color-scheme: dark) /* chtml maction */');
		}
	],
	[
		MathJax._.output?.svg,
		'output/svg',
		() => {
			const { SVG } = MathJax._.output.svg_ts;
			switchToBSStyle(SVG.commonStyles);
			const { SvgMaction } = MathJax._.output.svg.Wrappers.maction;
			switchToBSStyle(SvgMaction.styles, '@media (prefers-color-scheme: dark) /* svg maction */');
		}
	],
	[
		MathJax._.ui?.menu,
		'ui/menu',
		() => {
			// Apply selected theme to the context menu.
			const { Menu } = MathJax._.ui.menu.Menu;
			const initMenu = Menu.prototype.initMenu;
			Menu.prototype.initMenu = function () {
				initMenu.call(this);
				const sheet = this.document.document.getElementById?.('MJX-Menu-styles')?.sheet;
				if (!sheet) return;
				for (let i = sheet.cssRules.length - 1; i >= 0; --i) {
					const rule = sheet.cssRules[i];
					if (!(rule instanceof CSSMediaRule) || !/prefers-color-scheme:\s*dark/.test(rule.conditionText))
						continue;
					const rules = Array.from(rule.cssRules, (r) => `[data-bs-theme='dark'] ${r.cssText}`);
					sheet.deleteRule(i);
					for (const css of rules.reverse()) sheet.insertRule(css, i);
				}
			};
		}
	]
]) {
	if (immediate) {
		ready();
	} else {
		const config = MathJax.config.loader;
		config[extension] ??= {};
		config[extension].extraLoads ??= [];
		const check = config[extension].checkReady;
		config[extension].checkReady = async () => {
			if (check) await check();
			return ready();
		};
	}
}
