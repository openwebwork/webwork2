'use strict';

/* global MathQuill, $, bootstrap */

// Global list of all MathQuill answer inputs.
window.answerQuills = {};

(() => {
	// initialize MathQuill
	const MQ = MathQuill.getInterface(2);

	const setupMQInput = (mq_input) => {
		const answerLabel = mq_input.id.replace(/^MaThQuIlL_/, '');
		const input = $('#' + answerLabel);
		const inputType = input.attr('type');
		if (typeof(inputType) != 'string' || inputType.toLowerCase() !== 'text' || !input.hasClass('codeshard')) return;

		const answerQuill = $("<span id='mq-answer-" + answerLabel + "'></span>");
		answerQuill.input = input;
		input.addClass('mq-edit');
		answerQuill.latexInput = $(mq_input);

		input.after(answerQuill);

		// Default options.
		const cfgOptions = {
			spaceBehavesLikeTab: true,
			leftRightIntoCmdGoes: 'up',
			restrictMismatchedBrackets: true,
			sumStartsWithNEquals: true,
			supSubsRequireOperand: true,
			autoCommands: 'pi sqrt root vert inf union abs',
			rootsAreExponents: true,
			maxDepth: 10
		};

		// Merge options that are set by the problem.
		const optOverrides = answerQuill.latexInput.data('mq-opts');
		if (typeof(optOverrides) == 'object') $.extend(cfgOptions, optOverrides);

		// This is after the option merge to prevent handlers from being overridden.
		cfgOptions.handlers = {
			edit: (mq) => {
				if (mq.text() !== '') {
					answerQuill.input.val(mq.text().trim());
					answerQuill.latexInput
						.val(mq.latex().replace(/^(?:\\\s)*(.*?)(?:\\\s)*$/, '$1'));
				} else {
					answerQuill.input.val('');
					answerQuill.latexInput.val('');
				}
			},
			// Disable the toolbar when a text block is entered.
			textBlockEnter: () => {
				if (answerQuill.toolbar)
					answerQuill.toolbar.find('button').prop('disabled', true);
			},
			// Re-enable the toolbar when a text block is exited.
			textBlockExit: () => {
				if (answerQuill.toolbar)
					answerQuill.toolbar.find('button').prop('disabled', false);
			}
		};

		answerQuill.mathField = MQ.MathField(answerQuill[0], cfgOptions);

		answerQuill.textarea = answerQuill.find('textarea');

		answerQuill.buttons = [
			{ id: 'frac', latex: '/', tooltip: 'fraction (/)', icon: '\\frac{\\text{ }}{\\text{ }}' },
			{ id: 'abs', latex: '|', tooltip: 'absolute value (|)', icon: '|\\text{ }|' },
			{ id: 'sqrt', latex: '\\sqrt', tooltip: 'square root (sqrt)', icon: '\\sqrt{\\text{ }}' },
			{ id: 'nthroot', latex: '\\root', tooltip: 'nth root (root)', icon: '\\sqrt[\\text{ }]{\\text{ }}' },
			{ id: 'exponent', latex: '^', tooltip: 'exponent (^)', icon: '\\text{ }^\\text{ }' },
			{ id: 'infty', latex: '\\infty', tooltip: 'infinity (inf)', icon: '\\infty' },
			{ id: 'pi', latex: '\\pi', tooltip: 'pi (pi)', icon: '\\pi' },
			{ id: 'vert', latex: '\\vert', tooltip: 'such that (vert)', icon: '|' },
			{ id: 'cup', latex: '\\cup', tooltip: 'union (union)', icon: '\\cup' },
			// { id: 'leq', latex: '\\leq', tooltip: 'less than or equal (<=)', icon: '\\leq' },
			// { id: 'geq', latex: '\\geq', tooltip: 'greater than or equal (>=)', icon: '\\geq' },
			{ id: 'text', latex: '\\text', tooltip: 'text mode (")', icon: 'Tt' }
		];

		// Open the toolbar when the mathquill answer box gains focus.
		answerQuill.textarea.on('focusin', () => {
			if (answerQuill.toolbar) return;
			answerQuill.toolbar = $("<div class='quill-toolbar'>" +
				answerQuill.buttons.reduce(
					(returnString, curButton) => {
						return returnString +
							"<button type='button' id='" + curButton.id + '-' + answerQuill.attr('id') +
							"' class='symbol-button btn btn-inverse' " +
							"' data-latex='" + curButton.latex +
							"' data-toggle='tooltip' title='" + curButton.tooltip + "'>" +
							"<span id='icon-" + curButton.id + '-' + answerQuill.attr('id') + "'>"
							+ curButton.icon +
							'</span>' +
							'</button>';
					}, ''
				) + '</div>');
			answerQuill.toolbar.appendTo(document.body);

			answerQuill.toolbar.find('.symbol-button').each(function() {
				MQ.StaticMath($('#icon-' + this.id)[0]);
			});

			// There is a bug in bootstrap version 2.3.2 that makes the "placement: left" option fail for tooltips.
			// This ugly hackery fixes the position of the tooltip.
			function positionTooltip(tooltip, element) {
				var $tooltip = $(tooltip);
				$tooltip.css('display', 'none');
				$tooltip.find('.tooltip-inner').css('display', 'none');
				var $element = $(element);
				setTimeout(function () {
					$tooltip.css('display', 'block');
					$tooltip.find('.tooltip-inner').css({ whiteSpace: 'nowrap', display: 'block' });
					$tooltip.addClass('left')
						.css({
							top: ($element.position().top + ($element.outerHeight() - $tooltip.outerHeight()) / 2) + 'px',
							right: answerQuill.toolbar.width() - $element.position().left + 'px',
							left: 'unset'
						});
					$tooltip.find('.tooltip-arrow').css({ left: 'unset' });
					$tooltip.addClass('in');
				}, 0);
			}

			$('.symbol-button[data-toggle="tooltip"]').tooltip({
				trigger: 'hover', placement: positionTooltip, delay: { show: 500, hide: 0 }
			});

			$('.symbol-button').on('click', function() {
				answerQuill.mathField.cmd(this.getAttribute('data-latex'));
				answerQuill.textarea.focus();
			});

			// This is covered by css for the standard toolbar sizes.  However, if buttons are added or removed from the
			// toolbar by the problem or if the window height is excessively small, those may be incorrect.  So this
			// adjusts the width in those cases.
			const adjustWidth = () => {
				if (!answerQuill.toolbar) return;
				const left = answerQuill.toolbar.find('.symbol-button:first-child')[0].getBoundingClientRect().left;
				const right = answerQuill.toolbar.find('.symbol-button:last-child')[0].getBoundingClientRect().right;
				answerQuill.toolbar.css({ width: `${right - left + 8}px` });
			};
			$(window).on('resize.adjustWidth', adjustWidth);
			setTimeout(adjustWidth);
		});

		answerQuill.textarea.on('focusout', (e) => {
			if (e.relatedTarget && (e.relatedTarget.closest('.quill-toolbar') ||
				e.relatedTarget.classList.contains('symbol-button')))
				return;
			if (answerQuill.toolbar) {
				$(window).off('resize.adjustWidth');
				answerQuill.toolbar.remove();
				delete answerQuill.toolbar;
			}
		});

		// Trigger an answer preview when the enter key is pressed in an answer box.
		answerQuill.on('keypress.preview', (e) => {
			if (e.key == 'Enter') {
				// For homework
				$('#previewAnswers_id').trigger('click');
				// For gateway quizzes
				$('input[name=previewAnswers]').trigger('click');
			}
		});

		answerQuill.mathField.latex(answerQuill.latexInput.val());
		answerQuill.mathField.moveToLeftEnd();
		answerQuill.mathField.blur();

		// Give the mathquill answer box the correct/incorrect colors.
		setTimeout(() => {
			if (answerQuill.input.hasClass('correct')) answerQuill.addClass('correct');
			else if (answerQuill.input.hasClass('incorrect')) answerQuill.addClass('incorrect');
		}, 300);

		// Replace the result table correct/incorrect javascript that gives focus
		// to the original input, with javascript that gives focus to the mathquill
		// answer box.
		const resultsTableRows = $('table.attemptResults tr:not(:first-child)');
		if (resultsTableRows.length) {
			resultsTableRows.each(function() {
				const result = $(this).find('td > a');
				const href = result.attr('href');
				if (result.length && href !== undefined && href.indexOf(answerLabel) != -1) {
					// Set focus to the mathquill answer box if the correct/incorrect link is clicked.
					result.attr('href',
						"javascript:void(window.answerQuills['" + answerLabel + "'].textarea.focus())");
				}
			}
			);
		}

		window.answerQuills[answerLabel] = answerQuill;
	};

	// Set up MathQuill inputs that are already in the page.
	document.querySelectorAll('[id^=MaThQuIlL_]').forEach((input) => setupMQInput(input));

	// Observer that sets up MathQuill inputs.
	const observer = new MutationObserver((mutationsList) => {
		mutationsList.forEach((mutation) => {
			mutation.addedNodes.forEach((node) => {
				if (node instanceof Element) {
					if (node.id && node.id.startsWith('MaThQuIlL_')) {
						setupMQInput(node);
					} else {
						node.querySelectorAll('input[id^=MaThQuIlL_]').forEach((input) => {
							setupMQInput(input);
						});
					}
				}
			});
		});
	});
	observer.observe(document.body, { childList: true, subtree: true });

	// Stop the mutation observer when the window is closed.
	window.addEventListener('unload', () => observer.disconnect());
})();
