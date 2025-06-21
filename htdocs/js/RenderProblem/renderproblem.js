(() => {
	// renderElement may either be the id of an html element, or directly an html element.
	// If it is an html element, then that element must have an id.
	webworkConfig.renderProblem = (renderElement, renderOptions) =>
		new Promise((resolve) => {
			const renderArea =
				renderElement instanceof Element ? renderElement : document.getElementById(renderElement);
			if (!renderArea || !renderArea.id) return resolve();

			let iframe = renderArea.querySelector(`#${renderArea.id}_iframe`);
			if (iframe && iframe.iFrameResizer) iframe.contentDocument.location.replace('about:blank');

			const ro = {
				courseID: document.getElementsByName('hidden_course_id')[0]?.value,
				language: document.getElementsByName('hidden_language')[0]?.value ?? 'en',
				displayMode: document.getElementById('problem_displaymode').value ?? 'MathJax',
				problemSeed: 1,
				permissionLevel: 10,
				outputformat: 'simple',
				showAnswerNumbers: 0,
				showHints: 1,
				showSolutions: 1,
				showCorrectAnswersOnlyButton: 1,
				isInstructor: 1,
				forceScaffoldsOpen: 1,
				noprepostambles: 1,
				processAnswers: 0,
				showFooter: 0,
				send_pg_flags: 1,
				extra_header_text:
					'<style>' +
					'html{overflow-y:hidden;}body{padding:1px;background:#f5f5f5;}.container-fluid{padding:0px;}' +
					'</style>',
				...renderOptions
			};

			const user = document.getElementsByName('user')[0];
			if (user) ro.user = user.value;
			const sessionKey = document.getElementsByName('key')[0];
			if (sessionKey) ro.key = sessionKey.value;

			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), 10000);

			fetch(`${webworkConfig?.webwork_url ?? '/webwork2'}/render_rpc`, {
				method: 'post',
				mode: 'same-origin',
				body: new URLSearchParams(ro),
				signal: controller.signal
			})
				.then((response) => {
					clearTimeout(timeoutId);
					return response.json();
				})
				.then((data) => {
					// If the error is set, show that.
					if (data.error) throw data.error;
					// This shouldn't happen if the error is not set.
					if (!data.html) throw 'A server error occurred.  The response had no content.';
					if (/this problem file was empty/i.test(data.html)) throw 'No such file or file was empty!';
					// Give nicer problem rendering error
					if (
						(data.pg_flags && data.pg_flags.error_flag) ||
						/error caught by translator while processing problem/i.test(data.html)
					)
						throw 'There was an error rendering this problem!';

					if (!(iframe && iframe.iFrameResizer)) {
						iframe = document.createElement('iframe');
						iframe.id = `${renderArea.id}_iframe`;
						iframe.style.border = 'none';
						while (renderArea.firstChild) renderArea.firstChild.remove();
						renderArea.append(iframe);

						if (data.pg_flags && data.pg_flags.comment) {
							const container = document.createElement('div');
							container.innerHTML = data.pg_flags.comment;
							iframe.after(container);
						}
						if (data.deprecated_macros?.length) {
							const container = document.createElement('div');
							container.classList.add('alert', 'alert-danger');
							container.innerHTML =
								'Warning!! This problem uses the following deprecated macros:' +
								'<ul class="mb-0">' +
								data.deprecated_macros.reduce((acc, item) => `${acc}<li>${item}</li>`, '') +
								'</ul>If this is an OPL problem, please report this issue to the OPL. ' +
								'If this is a custom problem, please update the problem to use modern macros.';
							iframe.after(container);
						}
						iFrameResize(
							{
								checkOrigin: false,
								warningTimeout: 20000,
								scrolling: 'omit',
								heightCalculationMethod: 'taggedElement'
							},
							iframe
						);
						iframe.addEventListener('load', () => resolve());
					}
					iframe.srcdoc = data.html;
				})
				.catch((err) => {
					renderArea.innerHTML = `<div class="alert alert-danger p-1 mb-0 fw-bold">${
						err?.message ?? err
					}</div>`;
					resolve();
				});
		});
})();
