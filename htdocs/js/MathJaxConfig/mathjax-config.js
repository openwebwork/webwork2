if (!window.MathJax) {
	window.MathJax = {
		tex: {
			packages: {'[+]': ['noerrors']}
		},
		loader: { load: ['input/asciimath', '[tex]/noerrors'] },
		startup: {
			ready: function() {
				var AM = MathJax.InputJax.AsciiMath.AM;
				// modify existing AsciiMath triggers
				var i = AM.names.indexOf('**');
				AM.symbols[i] = { input: "**", tag: "msup", output: "^", tex: null, ttype: AM.TOKEN.INFIX };

				i = AM.names.indexOf('infty');
				AM.names[i] = 'infinity';
				AM.symbols[i] = { input:"infinity", tag:"mo", output:"\u221E", tex:"infty", ttype:AM.TOKEN.CONST };

				// add AsciiMath triggers for consistency with MathObjects
				var newTriggers = {
					inf:     {precedes:'infinity',   symbols:{tag:"mo",    output:"\u221E",          tex:"infty",    ttype:AM.TOKEN.CONST}},
					Infinity:{precedes:'Lambda',     symbols:{tag:"mo",    output:"\u221E",          tex:"infty",    ttype:AM.TOKEN.CONST}},
					Inf:     {precedes:'Infinity',   symbols:{tag:"mo",    output:"\u221E",          tex:"infty",    ttype:AM.TOKEN.CONST}},
					INFINITY:{precedes:'Inf',        symbols:{tag:"mo",    output:"\u221E",          tex:"infty",    ttype:AM.TOKEN.CONST}},
					INF:     {precedes:'INFINITY',   symbols:{tag:"mo",    output:"\u221E",          tex:"infty",    ttype:AM.TOKEN.CONST}},
					none:    {precedes:'norm',       symbols:{tag:"mtext", output:"NONE",            tex:null,       ttype:AM.TOKEN.CONST}},
					None:    {precedes:'O/',         symbols:{tag:"mtext", output:"NONE",            tex:null,       ttype:AM.TOKEN.CONST}},
					NONE:    {precedes:'None',       symbols:{tag:"mtext", output:"NONE",            tex:null,       ttype:AM.TOKEN.CONST}},
					dne:     {precedes:'dot',        symbols:{tag:"mtext", output:"DNE",             tex:null,       ttype:AM.TOKEN.CONST}},
					Dne:     {precedes:'EE',         symbols:{tag:"mtext", output:"DNE",             tex:null,       ttype:AM.TOKEN.CONST}},
					DNE:     {precedes:'Delta',      symbols:{tag:"mtext", output:"DNE",             tex:null,       ttype:AM.TOKEN.CONST}},
					Re:      {precedes:'Rightarrow', symbols:{tag:"mi",    output:"Re",              tex:null,       ttype:AM.TOKEN.UNARY, func:true}},
					Im:      {precedes:'Inf',        symbols:{tag:"mi",    output:"Im",              tex:null,       ttype:AM.TOKEN.UNARY, func:true}},
					log10:   {precedes:'lt',         symbols:{tag:"mi",    output:"log\u2081\u2080", tex:"log_{10}", ttype:AM.TOKEN.UNARY, func:true}},
					U:       {precedes:'Xi',         symbols:{tag:"mo",    output:"\u222A",          tex:"cup",      ttype:AM.TOKEN.CONST}},
					'><':    {precedes:'><|',        symbols:{tag:"mo",    output:"\u00D7",          tex:"times",    ttype:AM.TOKEN.CONST}},
				};
				for (const trigger in newTriggers) {
					var i = AM.names.indexOf(newTriggers[trigger].precedes);
					AM.names.splice(i, 0, trigger);
					AM.symbols.splice(i, 0, {input:trigger, ...newTriggers[trigger].symbols});
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
