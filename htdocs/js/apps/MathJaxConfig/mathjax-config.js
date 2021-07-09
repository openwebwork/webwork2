if (!window.MathJax) {
	window.MathJax = {
		tex: {
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
		},
		options: {
			renderActions: {
				findScript: [10, function (doc) {
					document.querySelectorAll('script[type^="math/tex"]').forEach(function(node) {
						var display = !!node.type.match(/; *mode=display/);
						var math = new doc.options.MathItem(node.textContent, doc.inputJax[0], display);
						var text = document.createTextNode('');
						node.parentNode.replaceChild(text, node);
						math.start = {node: text, delim: '', n: 0};
						math.end = {node: text, delim: '', n: 0};
						doc.math.push(math);
					});
				}, '']
			},
			ignoreHtmlClass: 'tex2jax_ignore'
		}

	};
}
