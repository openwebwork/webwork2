if (MathJax.loader) MathJax.loader.checkVersion('[no-dark-mode]', '4.1.0', 'extension');

for (const [immediate, extension, ready] of [
	[
		MathJax._.ui?.dialog,
		'core',
		() => {
			const { DraggableDialog } = MathJax._.ui.dialog.DraggableDialog;
			delete DraggableDialog.styles['@media (prefers-color-scheme: dark)'];
		}
	],

	[
		MathJax._.a11y?.explorer,
		'a11y/explorer',
		() => {
			const Region = MathJax._.a11y.explorer.Region;
			for (const region of ['LiveRegion', 'HoverRegion', 'ToolTip']) {
				Region[region].style.styles['@media (prefers-color-scheme: dark)'] = {};
			}
			Region.LiveRegion.style.styles['@media (prefers-color-scheme: dark)']['mjx-ignore'] = { ignore: 1 };
			MathJax.startup.extendHandler((handler) => {
				delete handler.documentClass.speechStyles['@media (prefers-color-scheme: dark) /* explorer */'];
				return handler;
			});
		}
	],

	[
		MathJax._.output?.chtml,
		'output/chtml',
		() => {
			const { CHTML } = MathJax._.output.chtml_ts;
			delete CHTML.commonStyles['@media (prefers-color-scheme: dark)'];
			const { ChtmlMaction } = MathJax._.output.chtml.Wrappers.maction;
			delete ChtmlMaction.styles['@media (prefers-color-scheme: dark) /* chtml maction */'];
		}
	],

	[
		MathJax._.output?.svg,
		'output/svg',
		() => {
			const { SVG } = MathJax._.output.svg_ts;
			delete SVG.commonStyles['@media (prefers-color-scheme: dark)'];
			const { SvgMaction } = MathJax._.output.svg.Wrappers.maction;
			delete SvgMaction.styles['@media (prefers-color-scheme: dark) /* svg maction */'];
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
