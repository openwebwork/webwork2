// initialize MathQuill
var MQ = MathQuill.getInterface(2);
answerQuills = {};

// Avoid conflicts with bootstrap.
$.widget.bridge('uitooltip', $.ui.tooltip);

function createAnswerQuill() {
	var answerLabel = this.id.replace(/^MaThQuIlL_/, "");
	var input = $("#" + answerLabel);
	var inputType = input.attr('type');
	if (typeof(inputType) != 'string' || inputType.toLowerCase() !== "text") return;

	var answerQuill = $("<span id='mq-answer-" + answerLabel + "'></span>");
	answerQuill.input = input;
	answerQuill.latexInput = $(this);

	input.after(answerQuill);

	// Default options.
	var cfgOptions = {
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
	if (this.id + '_Opts' in window)
		$.extend(cfgOptions, cfgOptions, window[this.id + '_Opts']);

	// This is after the option merge to prevent handlers from being overridden.
	cfgOptions.handlers = {
		edit: function(mq) {
			if (mq.text() !== "") {
				answerQuill.input.val(mq.text().trim());
				answerQuill.latexInput
					.val(mq.latex().replace(/^(?:\\\s)*(.*?)(?:\\\s)*$/, '$1'));
			} else {
				answerQuill.input.val('');
				answerQuill.latexInput.val('');
			}
		},
		// Disable the toolbar when a text block is entered.
		textBlockEnter: function() {
			if (answerQuill.toolbar)
				answerQuill.toolbar.find("button").prop("disabled", true);
		},
		// Re-enable the toolbar when a text block is exited.
		textBlockExit: function() {
			if (answerQuill.toolbar)
				answerQuill.toolbar.find("button").prop("disabled", false);
		}
	};

	answerQuill.mathField = MQ.MathField(answerQuill[0], cfgOptions);

	answerQuill.textarea = answerQuill.find("textarea");

	answerQuill.hasFocus = false;

	answerQuill.buttons = [
		{ id: 'frac', latex: '/', tooltip: 'fraction (/)', icon: '\\frac{\\text{\ \ }}{\\text{\ \ }}' },
		{ id: 'abs', latex: '|', tooltip: 'absolute value (|)', icon: '|\\text{\ \ }|' },
		{ id: 'sqrt', latex: '\\sqrt', tooltip: 'square root (sqrt)', icon: '\\sqrt{\\text{\ \ }}' },
		{ id: 'nthroot', latex: '\\root', tooltip: 'nth root (root)', icon: '\\sqrt[\\text{\ \ }]{\\text{\ \ }}' },
		{ id: 'exponent', latex: '^', tooltip: 'exponent (^)', icon: '\\text{\ \ }^\\text{\ \ }' },
		{ id: 'infty', latex: '\\infty', tooltip: 'infinity (inf)', icon: '\\infty' },
		{ id: 'pi', latex: '\\pi', tooltip: 'pi (pi)', icon: '\\pi' },
		{ id: 'vert', latex: '\\vert', tooltip: 'such that (vert)', icon: '|' },
		{ id: 'cup', latex: '\\cup', tooltip: 'union (union)', icon: '\\cup' },
		// { id: 'leq', latex: '\\leq', tooltip: 'less than or equal (<=)', icon: '\\leq' },
		// { id: 'geq', latex: '\\geq', tooltip: 'greater than or equal (>=)', icon: '\\geq' },
		{ id: 'text', latex: '\\text', tooltip: 'text mode (")', icon: 'Tt' }
	];

	// Open the toolbar when the mathquill answer box gains focus.
	answerQuill.textarea.on('focusin', function() {
		answerQuill.hasFocus = true;
		if (answerQuill.toolbar) return;
		answerQuill.toolbar = $("<div class='quill-toolbar'>" +
			answerQuill.buttons.reduce(
				function(returnString, curButton) {
					return returnString +
						"<button id='" + curButton.id + "-" + answerQuill.attr('id') +
						"' class='symbol-button btn' " +
						"' data-latex='" + curButton.latex +
						"' data-tooltip='" + curButton.tooltip + "'>" +
						"<span id='icon-" + curButton.id + "-" + answerQuill.attr('id') + "'>"
						+ curButton.icon +
						"</span>" +
						"</button>";
				}, ""
			) + "</div>");
		answerQuill.toolbar.appendTo(document.body);

		answerQuill.toolbar.find(".symbol-button").each(function() {
			MQ.StaticMath($("#icon-" + this.id)[0]);
		});

		$(".symbol-button").uitooltip( {
			items: "[data-tooltip]",
			position: {my: "right center", at: "left-5px center"},
			show: {delay: 500, effect: "none"},
			hide: {delay: 0, effect: "none"},
			content: function() {
				var element = $(this);
				if (element.prop("disabled")) return;
				if (element.is("[data-tooltip]")) { return element.attr("data-tooltip"); }
			}
		});

		$(".symbol-button").on("click", function() {
			answerQuill.hasFocus = true;
			answerQuill.mathField.cmd(this.getAttribute("data-latex"));
			answerQuill.textarea.focus();
		});
	});

	answerQuill.textarea.on('focusout', function() {
		answerQuill.hasFocus = false;
		setTimeout(function() {
			if (!answerQuill.hasFocus && answerQuill.toolbar)
			{
				answerQuill.toolbar.remove();
				delete answerQuill.toolbar;
			}
		}, 200);
	});

	// Trigger an answer preview when the enter key is pressed in an answer box.
	answerQuill.on('keypress.preview', function(e) {
		if (e.key == 'Enter' || e.which == 13 || e.keyCode == 13) {
			// For homework
			$("#previewAnswers_id").trigger('click');
			// For gateway quizzes
			$("input[name=previewAnswers]").trigger('click');
		}
	});

	answerQuill.mathField.latex(answerQuill.latexInput.val());
	answerQuill.mathField.moveToLeftEnd();
	answerQuill.mathField.blur();

	// Give the mathquill answer box the correct/incorrect colors.
	setTimeout(function() {
		if (answerQuill.input.hasClass('correct')) answerQuill.addClass('correct');
		else if (answerQuill.input.hasClass('incorrect')) answerQuill.addClass('incorrect');
	}, 300);

	// Replace the result table correct/incorrect javascript that gives focus
	// to the original input, with javascript that gives focus to the mathquill
	// answer box.
	var resultsTableRows = jQuery("table.attemptResults tr:not(:first-child)");
	if (resultsTableRows.length)
	{
		resultsTableRows.each(function()
			{
				var result = $(this).find("td > a");
				var href = result.attr('href');
				if (result.length && href !== undefined && href.indexOf(answerLabel) != -1)
				{
					// Set focus to the mathquill answer box if the correct/incorrect link is clicked.
					result.attr('href',
						"javascript:void(window.answerQuills['" + answerLabel + "'].textarea.focus())");
				}
			}
		);
	}

	answerQuills[answerLabel] = answerQuill;
}

$(function() { $("[id^=MaThQuIlL_]").each(createAnswerQuill); });
