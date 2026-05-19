if (MathJax.loader) MathJax.loader.checkVersion('[bs-color-scheme]', '4.1.1', 'extension');

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

					// The variable --mjx-bg1-color is defined to be 'rgba(var(--mjx-bg-blue), var(--mjx-bg-alpha))'.
					// I suspect this is a typo as the variable -mjx-bg-alpha is not defined anywhere. In any case this
					// change is needed to get the correct background color on the focused element in the explorer.
					Region[region].style.styles["[data-bs-theme='light']"]['--mjx-bg1-color'] =
						'rgba(var(--mjx-bg-blue), var(--mjx-bg1-alpha))';
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
