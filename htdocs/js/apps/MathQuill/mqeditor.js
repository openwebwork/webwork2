// initialize MathQuill
var MQ = MathQuill.getInterface(2);

// Avoid conflicts with bootstrap.
jQuery.widget.bridge('uitooltip', jQuery.ui.tooltip);

function createAnswerQuill() {
	var answerLabel = this.id.replace(/^MaThQuIlL_/, "");
	var input = jQuery("#" + answerLabel);
	var inputType = input.attr('type');
	if (typeof(inputType) != 'string' || inputType.toLowerCase() !== "text") return false;
	var inputParent = input.parent();

	var answerQuill = jQuery("<span id='mq-answer-" + answerLabel + "'></span>");
	answerQuill.input = input;
	answerQuill.latexInput = jQuery(this);

	if (inputParent.hasClass('mv-container')) inputParent.after(answerQuill);
	else input.after(answerQuill);

	answerQuill.mathField = MQ.MathField(answerQuill[0], {
		spaceBehavesLikeTab: true,
		leftRightIntoCmdGoes: 'up',
		restrictMismatchedBrackets: true,
		sumStartsWithNEquals: true,
		supSubsRequireOperand: true,
		charsThatBreakOutOfSupSub: '+-=<>',
		autoSubscriptNumerals: true,
		autoCommands: 'pi sqrt root vert inf union',
		maxDepth: 10,
		handlers: {
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
		}
	});

	answerQuill.textarea = answerQuill.find("textarea");

	answerQuill.hasFocus = false;

	var buttons = {
		frac: { latex: '/', tooltip: 'fraction (/)', icon: '\\frac{\\text{\ \ }}{\\text{\ \ }}' },
		sqrt: { latex: '\\sqrt', tooltip: 'square root (sqrt)', icon: '\\sqrt{\\text{\ \ }}' },
		nthroot: { latex: '\\root', tooltip: 'nth root (root)', icon: '\\sqrt[\\text{\ \ }]{\\text{\ \ }}' },
		exponent: { latex: '^', tooltip: 'exponent (^)', icon: '\\text{\ \ }^\\text{\ \ }' },
		infty: { latex: '\\infty', tooltip: 'infinity (inf)', icon: '\\infty' },
		pi: { latex: '\\pi', tooltip: 'pi (pi)', icon: '\\pi' },
		cap: { latex: '\\cap', tooltip: 'intersection (\\cap)', icon: '\\cap' },
		cup: { latex: '\\cup', tooltip: 'union (union)', icon: '\\cup' },
		leq: { latex: '\\leq', tooltip: 'less than or equal (\\leq)', icon: '\\leq' },
		geq: { latex: '\\geq', tooltip: 'Greater Than or Equal (\\geq)', icon: '\\geq' }
	};

	answerQuill.textarea.on('focusin', function() {
		answerQuill.hasFocus = true;
		if (answerQuill.toolbar) return;
		answerQuill.toolbar = jQuery("<div class='quill-toolbar'>" +
			Object.entries(buttons).reduce(
				function(returnString, curButton) {
					return returnString +
						"<button id='" + curButton[0] + "-" + answerQuill.attr('id') +
						"' class='symbol-button btn' " +
						"data-latex='" + curButton[1].latex +
						"' data-tooltip='" + curButton[1].tooltip + "'>" +
						"<span id='icon-" + curButton[0] + "-" + answerQuill.attr('id') + "'>"
						+ curButton[1].icon +
						"</span>" +
						"</button>";
				}, ""
			) + "</div>");
		answerQuill.toolbar.appendTo(document.body);

		answerQuill.toolbar.find(".symbol-button").each(function() {
			MQ.StaticMath(jQuery("#icon-" + this.id)[0]);
		});

		jQuery(".symbol-button").uitooltip( {
			items: "[data-tooltip]",
			position: {my: "right center", at: "left-5px center"},
			show: {delay: 500, effect: "none"},
			hide: {delay: 0, effect: "none"},
			content: function() {
				var element = jQuery(this);
				if (element.is("[data-tooltip]")) { return element.attr("data-tooltip"); }
			}
		});

		jQuery(".symbol-button").on("click", function() {
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

	answerQuill.mathField.latex(answerQuill.latexInput.val());
	answerQuill.mathField.moveToLeftEnd();
	answerQuill.mathField.blur();

	setTimeout(function() {
		if (answerQuill.input.hasClass('correct')) answerQuill.addClass('correct');
		else if (answerQuill.input.hasClass('incorrect')) answerQuill.addClass('incorrect');
	}, 300);

	return answerQuill;
}

$(function() { $("[id^=MaThQuIlL_]").each(createAnswerQuill); });
