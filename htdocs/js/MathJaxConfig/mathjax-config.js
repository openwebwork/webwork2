if (!window.MathJax) {
	const problems = [];

	window.MathJax = {
		tex: { packages: { '[+]': webworkConfig?.showMathJaxErrors ? [] : ['noerrors'] } },
		loader: {
			load: ['input/asciimath', '[tex]/noerrors', '[bs-color-scheme]'],
			paths: { 'bs-color-scheme': webworkConfig?.mathJaxBSColorSchemeUrl ?? './bs-color-scheme.js' }
		},
		startup: {
			ready() {
				const AM = MathJax.InputJax.AsciiMath.AM;

				// Modify existing AsciiMath triggers.
				AM.symbols[AM.names.indexOf('**')] = {
					input: '**',
					tag: 'msup',
					output: '^',
					tex: null,
					ttype: AM.TOKEN.INFIX
				};

				const i = AM.names.indexOf('infty');
				AM.names[i] = 'infinity';
				AM.symbols[i] = { input: 'infinity', tag: 'mo', output: '\u221E', tex: 'infty', ttype: AM.TOKEN.CONST };

				// Add AsciiMath triggers for consistency with MathObjects.
				const newTriggers = {
					inf: {
						precedes: 'infinity',
						symbols: { tag: 'mo', output: '\u221E', tex: 'infty', ttype: AM.TOKEN.CONST }
					},
					Infinity: {
						precedes: 'Lambda',
						symbols: { tag: 'mo', output: '\u221E', tex: 'infty', ttype: AM.TOKEN.CONST }
					},
					Inf: {
						precedes: 'Infinity',
						symbols: { tag: 'mo', output: '\u221E', tex: 'infty', ttype: AM.TOKEN.CONST }
					},
					INFINITY: {
						precedes: 'Inf',
						symbols: { tag: 'mo', output: '\u221E', tex: 'infty', ttype: AM.TOKEN.CONST }
					},
					INF: {
						precedes: 'INFINITY',
						symbols: { tag: 'mo', output: '\u221E', tex: 'infty', ttype: AM.TOKEN.CONST }
					},
					none: {
						precedes: 'norm',
						symbols: { tag: 'mtext', output: 'NONE', tex: null, ttype: AM.TOKEN.CONST }
					},
					None: {
						precedes: 'O/',
						symbols: { tag: 'mtext', output: 'NONE', tex: null, ttype: AM.TOKEN.CONST }
					},
					NONE: {
						precedes: 'None',
						symbols: { tag: 'mtext', output: 'NONE', tex: null, ttype: AM.TOKEN.CONST }
					},
					dne: {
						precedes: 'dot',
						symbols: { tag: 'mtext', output: 'DNE', tex: null, ttype: AM.TOKEN.CONST }
					},
					Dne: {
						precedes: 'EE',
						symbols: { tag: 'mtext', output: 'DNE', tex: null, ttype: AM.TOKEN.CONST }
					},
					DNE: {
						precedes: 'Delta',
						symbols: { tag: 'mtext', output: 'DNE', tex: null, ttype: AM.TOKEN.CONST }
					},
					Re: {
						precedes: 'Rightarrow',
						symbols: { tag: 'mi', output: 'Re', tex: null, ttype: AM.TOKEN.UNARY, func: true }
					},
					Im: {
						precedes: 'Inf',
						symbols: { tag: 'mi', output: 'Im', tex: null, ttype: AM.TOKEN.UNARY, func: true }
					},
					log10: {
						precedes: 'lt',
						symbols: {
							tag: 'mi',
							output: 'log\u2081\u2080',
							tex: 'log_{10}',
							ttype: AM.TOKEN.UNARY,
							func: true
						}
					},
					U: {
						precedes: 'Xi',
						symbols: { tag: 'mo', output: '\u222A', tex: 'cup', ttype: AM.TOKEN.CONST }
					},
					'><': {
						precedes: '><|',
						symbols: { tag: 'mo', output: '\u00D7', tex: 'times', ttype: AM.TOKEN.CONST }
					}
				};
				for (const trigger in newTriggers) {
					const i = AM.names.indexOf(newTriggers[trigger].precedes);
					AM.names.splice(i, 0, trigger);
					AM.symbols.splice(i, 0, { input: trigger, ...newTriggers[trigger].symbols });
				}

				MathJax.startup.defaultReady();
				MathJax.startup.document.constructor.ProcessBits.allocate('findScripts');
			},
			pageReady() {
				return MathJax.startup.defaultPageReady().then(() => {
					for (const [problemContent, loaderOverlay, resizeObserver] of problems) {
						resizeObserver.disconnect();
						loaderOverlay.remove();
						problemContent.style.visibility = '';
					}
					problems.length = 0;
				});
			}
		},
		options: {
			renderActions: {
				findScript: [
					10,
					(doc) => {
						if (doc.processed.isSet('findScripts')) return;
						const containers = doc.adaptor.getElements(doc.options.elements || [doc.document.body], doc);
						for (const container of containers) {
							for (const node of container.querySelectorAll('script[type^="math/tex"]')) {
								const math = new doc.options.MathItem(
									node.textContent,
									doc.inputJax[0],
									!!node.type.match(/; *mode=display/)
								);
								const text = document.createTextNode('');
								node.parentNode.replaceChild(text, node);
								math.start = { node: text, delim: '', n: 0 };
								math.end = { node: text, delim: '', n: 0 };
								doc.math.push(math);
							}
						}
						doc.processed.set('findScripts');
					},
					''
				]
			},
			ignoreHtmlClass: 'tex2jax_ignore'
		}
	};

	for (const problemContent of document.querySelectorAll('.problem-content')) {
		problemContent.style.visibility = 'hidden';
		const loaderOverlay = document.createElement('div');
		loaderOverlay.classList.add('problem-content');
		const bodyRectangle = problemContent.getBoundingClientRect();
		loaderOverlay.style.position = 'absolute';
		loaderOverlay.style.top = `${bodyRectangle.y}px`;
		loaderOverlay.style.left = `${bodyRectangle.x}px`;
		loaderOverlay.style.width = `${bodyRectangle.width}px`;
		loaderOverlay.style.height = `${bodyRectangle.height}px`;
		loaderOverlay.style.overflow = 'clip';
		loaderOverlay.style.transition = 'height 0.3s ease';
		loaderOverlay.animate([{ opacity: 1 }, { opacity: 0.2 }, { opacity: 1 }], {
			duration: 2000,
			iterations: Infinity,
			easing: 'ease-in-out'
		});
		loaderOverlay.style.cursor = 'wait';

		problemContent.after(loaderOverlay);
		const resizeObserver = new ResizeObserver(() => {
			const bodyRectangle = problemContent.getBoundingClientRect();
			loaderOverlay.style.top = `${bodyRectangle.top}px`;
			loaderOverlay.style.left = `${bodyRectangle.left}px`;
			loaderOverlay.style.width = `${bodyRectangle.width}px`;
			loaderOverlay.style.height = `${bodyRectangle.height}px`;
		});
		resizeObserver.observe(problemContent);
		problems.push([problemContent, loaderOverlay, resizeObserver]);
	}
}
