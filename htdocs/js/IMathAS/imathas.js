'use strict';

/* global initq, dopresubmit */

// Loads the IMathAS JavaScript that an IMathAS question inserted by the IMathAS.pl macro needs, initializes the
// question, and has IMathAS prepare its form fields when the problem form is submitted.

(() => {
	// The question number that embedq2.php of IMathAS uses.
	const qn = 5;

	const loadScript = (src) =>
		new Promise((resolve, reject) => {
			const script = document.createElement('script');
			script.src = src;
			script.async = false;
			script.onload = resolve;
			script.onerror = () => reject(new Error(`Unable to load ${src}`));
			document.head.append(script);
		});

	let scriptsLoaded;

	const loadIMathAS = (root) => {
		if (scriptsLoaded) return scriptsLoaded;

		// Globals that the IMathAS scripts expect the page to define.
		window.imasroot = root;
		window.staticroot = root;
		window.cid = 0;
		window.uselocaljs = true;
		window.usertype = 0;
		window.AMTcgiloc = '';

		// The answer entry tips of IMathAS are not used (the macro shows them as help links instead), but the
		// IMathAS scripts expect the elements that they are shown in to exist when a question is submitted.
		for (const id of ['ehdd', 'eh']) {
			if (document.getElementById(id)) continue;
			const element = document.createElement('div');
			element.id = id;
			element.hidden = true;
			document.body.append(element);
		}

		scriptsLoaded = (async () => {
			if (!window.jQuery) await loadScript(`${root}/javascript/jquery.min.js`);
			await loadScript(`${root}/javascript/general.js`);

			// IMathAS writes mathematics as AsciiMath in backticks.  The MathJax of the page is set up to typeset
			// that, so have the IMathAS scripts use it for anything that they need typeset.  These are the
			// settings that IMathAS uses when it uses MathJax.
			window.noMathRender = false;
			window.usingASCIIMath = true;
			window.AMnoMathML = true;
			window.MathJaxCompatible = true;
			window.mathRenderer = 'MathJax';
			window.rendermathnode = (node, callback) => {
				if (!window.MathJax?.typesetPromise) {
					// MathJax is not ready yet, so try again soon.
					setTimeout(() => window.rendermathnode(node, callback), 100);
					return;
				}
				window.MathJax.typesetPromise([node])
					.catch((e) => console.error(e))
					.then(() => {
						if (typeof callback === 'function') callback();
					});
			};

			await loadScript(`${root}/javascript/mathparser_min.js`);
			await loadScript(`${root}/javascript/ASCIIsvg_min.js`);
			window.usingASCIISvg = true;

			// The IMathAS scripts need the IMathAS version of MathQuill, and they configure it when they load.  So
			// set the MathQuill of the page aside while they load so that it is not replaced or reconfigured.
			const pageMathQuill = window.MathQuill;
			window.MathQuill = undefined;
			try {
				await loadScript(`${root}/mathquill/mathquill.min.js`);
				await loadScript(`${root}/javascript/assess2_min.js`);
				await loadScript(`${root}/javascript/assess2supp.js`);
			} finally {
				if (pageMathQuill) window.MathQuill = pageMathQuill;
			}
		})();

		return scriptsLoaded;
	};

	const setupQuestion = async (container) => {
		if (container.dataset.imathasInitialized) return;
		container.dataset.imathasInitialized = 'true';

		try {
			await loadIMathAS(container.dataset.publicUrl.replace(/\/$/, ''));

			const jsparams = JSON.parse(container.dataset.jsparams || '{}');
			jsparams.noMQ = true;

			initq(qn, jsparams);

			// IMathAS adds computed values of the responses to the form before it is submitted.
			container.closest('form')?.addEventListener('submit', () => {
				// Remove what was added for an earlier submission that did not leave the page.
				for (const input of container.querySelectorAll('input[type="hidden"][name$="-val"]')) input.remove();
				for (const input of container.querySelectorAll('input[type="hidden"][name$="-choicemap"]'))
					input.remove();

				// Change the things that the MathQuill editor of WeBWorK gives (or that those that use WeBWorK
				// have the habit of typing) for which IMathAS expects something else.  This is only done in the
				// answers for mathematical input.
				for (const input of container.querySelectorAll('input.codeshard[name^="qn"]')) {
					input.value = input.value
						.replace(/\b(?:inf|infinity)\b/gi, 'oo')
						.replace(/\bempty ?set\b/gi, 'DNE')
						.replace(/\bpm\b\s*/g, '+-')
						.replace(/&lang;/g, '<')
						.replace(/&rang;/g, '>');
				}

				dopresubmit(qn, false);
			});
		} catch (e) {
			console.error(e);
			const message = document.createElement('div');
			message.classList.add('alert', 'alert-danger');
			message.textContent = 'The scripts for this question could not be loaded.';
			container.prepend(message);
		}
	};

	const setupAll = (node) => {
		if (node.classList?.contains('imathas-question')) setupQuestion(node);
		for (const container of node.querySelectorAll?.('.imathas-question') ?? []) setupQuestion(container);
	};

	setupAll(document);

	// Deal with questions that are added to the page later.
	const observer = new MutationObserver((mutationsList) => {
		for (const mutation of mutationsList) {
			for (const node of mutation.addedNodes) setupAll(node);
		}
	});
	observer.observe(document.body, { childList: true, subtree: true });
})();
