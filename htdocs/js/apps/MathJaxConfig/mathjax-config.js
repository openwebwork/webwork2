if (!window.MathJax) {
	window.MathJax = {
		tex: {
			autoload: { color: [], colorV2: ['color'] },
			packages: {'[+]': ['noerrors']}
		},
		loader: { load: ['input/asciimath', '[tex]/noerrors'] },
		startup: {
			ready: function() {
				var AM = MathJax.InputJax.AsciiMath.AM;
				for (var i = 0; i < AM.symbols.length; i++) {
					if (AM.symbols[i].input == '**') {
						AM.symbols[i] = { input: "**", tag: "msup", output: "^", tex: null, ttype: AM.TOKEN.INFIX };
					}
				}
				return MathJax.startup.defaultReady()
			}
		}
	};
}
