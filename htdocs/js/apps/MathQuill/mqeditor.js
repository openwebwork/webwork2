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
		charsThatBreakOutOfSupSub: '=<>',
		autoSubscriptNumerals: true,
		autoCommands: 'pi sqrt root vert inf union abs',
		rootsAreExponents: true,
		maxDepth: 10
	};

	// Merge options that are set by the problem.
	if (this.id + '_Opts' in window)
		$.extend(cfgOptions, cfgOptions, window[this.id + '_Opts']);

	// This is after the option merge to preven handlers from being overridden.
	cfgOptions.handlers = {
		edit: function() {
			if (answerQuill.mathField.text() !== "") {
				answerQuill.input.val(answerQuill.mathField.text().trim());
				answerQuill.latexInput
					.val(answerQuill.mathField.latex().replace(/^(?:\\\s)*(.*?)(?:\\\s)*$/, '$1'));
			} else {
				answerQuill.input.val('');
				answerQuill.latexInput.val('');
			}
		}
	};

	answerQuill.mathField = MQ.MathField(answerQuill[0], cfgOptions);

	answerQuill.textarea = answerQuill.find("textarea");

	answerQuill.hasFocus = false;

	var buttons = {
		frac: { cmd: '/', latex: '/', tooltip: 'fraction (/)', icon: '\\frac{\\text{\ \ }}{\\text{\ \ }}' },
		abs: { cmd: 'abs', latex: '|', tooltip: 'absolute value (|)', icon: '|\\text{\ \ }|' },
		sqrt: { cmd: 'sqrt', latex: '\\sqrt', tooltip: 'square root (sqrt)', icon: '\\sqrt{\\text{\ \ }}' },
		nthroot: { cmd: 'root', latex: '\\root', tooltip: 'nth root (root)', icon: '\\sqrt[\\text{\ \ }]{\\text{\ \ }}' },
		exponent: { cmd: '^', latex: '^', tooltip: 'exponent (^)', icon: '\\text{\ \ }^\\text{\ \ }' },
		infty: { cmd: 'inf', latex: '\\infty', tooltip: 'infinity (inf)', icon: '\\infty' },
		pi: { cmd: 'pi', latex: '\\pi', tooltip: 'pi (pi)', icon: '\\pi' },
		vert: { cmd: 'vert', latex: '\\vert', tooltip: 'such that (|)', icon: '|' },
		cup: { cmd: 'U', latex: '\\cup', tooltip: 'union (union)', icon: '\\cup' },
		// leq: { cmd: '<=', latex: '\\leq', tooltip: 'less than or equal (\\leq)', icon: '\\leq' },
		// geq: { cmd: '>=', latex: '\\geq', tooltip: 'greater than or equal (\\geq)', icon: '\\geq' },
		text: { cmd: '"', latex: '\\text', tooltip: 'text mode (")', icon: 'Tt' }
	};

	// Open the toolbar when the mathquill answer box gains focus.
	answerQuill.textarea.on('focusin', function() {
		answerQuill.hasFocus = true;
		if (answerQuill.toolbar) return;
		answerQuill.toolbar = $("<div class='quill-toolbar'>" +
			Object.entries(buttons).reduce(
				function(returnString, curButton) {
					return returnString +
						"<button id='" + curButton[0] + "-" + answerQuill.attr('id') +
						"' class='symbol-button btn' " +
						"data-latex='" + curButton[1].latex +
						"' data-textcmd='" + curButton[1].cmd +
						"' data-tooltip='" + curButton[1].tooltip + "'>" +
						"<span id='icon-" + curButton[0] + "-" + answerQuill.attr('id') + "'>"
						+ curButton[1].icon +
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
				if (element.is("[data-tooltip]")) { return element.attr("data-tooltip"); }
			}
		});

		$(".symbol-button").on("click", function() {
			answerQuill.hasFocus = true;
			answerQuill.mathField.typedText(this.getAttribute("data-textcmd"));
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
