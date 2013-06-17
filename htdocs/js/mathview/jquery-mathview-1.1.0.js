// Class constructor
// Create the equation editor decorator around the decoratedTextBox and 
// generate PGML or LaTeX code depending ont the renderingMode option.
// params:
//    decoratedTextBox: the text box being decorated.
//    rederingMode: Either "PGML" to render PGML code or "LATEX" to render LaTeX code.

//console.log(location.search);

//Version
var Version = "1.1.0";

// BasePath for images
// Local Uncomment for local use
//var jqmv_basepath = "mathview/";// basepath for images

// Uncomment for Webwork Use
var jqmv_basepath =  "/webwork2_files/images/mathview/"


var mathView_textzone;
var apparitionZone;

$(document).ready(function() {

	$(function() {
		$('#equation').addMathEditor();
	});
});

function PopUpEquation() {
	this.renderingMode = "LATEX";
	MathJax.Hub.Config({
		menuSettings : {context : "Browser"},
		showProcessingMessages : false,
		TeX : {MultLineWidth : "50%"},
		styles : {
			"#viewer" : {
				"font-size" : "150%",
				"height" : "85px"
			},
			".ui-widget-content" : {
				"background" : "none",
				"padding-right" : "20px"
			},
			".ui-widget-content > ul" : {
				"text-align" : "center"
			},
			".ui-widget-header > ul" : {
				"text-align" : "center"
			},
			".classCat > li" : {
				"display" : "inline"
			}
		}
	});
	this.isVisible = false;
	var me = this;
	this.generateTex = function(strucValue) {
		var oldTex = null;
		if (me.decoratedTextBox.val() != null) {
			oldTex = me.decoratedTextBox.val();
		}
		if ($('#warning').length != 0) {
			$('#warning').remove();
		}
		if (me.renderingMode == "LATEX") {
			me.decoratedTextBox.insertAtCaret(strucValue.latex);
			var tex = me.decoratedTextBox.val();
			$('#viewer').html("$$" + tex + "$$");
			MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "viewer" ]);
		} else {
			if (me.renderingMode == "PGML") {
				me.decoratedTextBox.insertAtCaret(strucValue.PG);
				code = encodeURIComponent(me.decoratedTextBox.val());
				$.get('/webwork2/pgtotex?pgcode=' + code, function(data) {
					$('#viewer').html("$$" + data + "$$");
					MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "viewer" ]);
				});
			} else
				console.log('Invalid Rendering Mode');
		}
		var equWidth = $('#viewer').find('.MathJax').first().width();
		if (equWidth > 530) {
			if (equWidth > 800) {
				me.decoratedTextBox.val(oldTex);
				if (me.renderingMode == "LATEX") {
					$('#viewer').html("$$" + oldTex + "$$");
					MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "viewer" ]);
				} else {
					if (me.renderingMode == "PGML") {
						code = encodeURIComponent(me.decoratedTextBox.val());
						$.get('/webwork2/pgtotex?pgcode=' + code,
						function(data) {
							$('#viewer').html("$$" + data + "$$");
							MathJax.Hub.Queue([ "Typeset", MathJax.Hub,"viewer" ]);
						});
					}
				}
				$('#popupdiv').append($('<div>',
										{	id : 'warning',
											style : 'position: relative; border: solid black 1px; background-color:darkgrey;text-align: center;margin-left: auto;margin-right: auto;color: red;font-size: 24px;width: 350px;'
										}));

				$('#warning').html('Equation is too long.');

			} else {

				$('#popupdiv').css('width', equWidth + 20);

			}

		} else {

			$('#popupdiv').css('width', '530px');

		}

	};

	this.reGenerateTex = function(tbValue) {

		var oldTex = me.decoratedTextBox.val();

		if ($('#warning').length != 0) {

			$('#warning').remove();

			$('#popupdiv').css('width', '530px');

		}

		if (me.renderingMode == "LATEX") {

			$('#viewer').html("$$" + tbValue + "$$");

			MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "viewer" ]);

		} else {

			if (me.renderingMode == "PGML") {

				code = encodeURIComponent(tbValue);

				$.get('/webwork2/pgtotex?pgcode=' + code, function(data) {

					$('#viewer').html("$$" + data + "$$");

					MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "viewer" ]);

				});

			} else

				console.log('Invalid Rendering Mode');

		}

		var equWidth = $('#viewer').find('.MathJax').first().width();

		if (equWidth > 530) {

			if (equWidth >= 800) {

				me.decoratedTextBox.val(oldTex);

				if (me.renderingMode == "LATEX") {

					$('#viewer').html("$$" + oldTex + "$$");

					// reprocess the MathOutput Element

					MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "viewer" ]);

				} else {

					if (me.renderingMode == "PGML") {

						code = encodeURIComponent(me.decoratedTextBox.val());

						$.get('/webwork2/pgtotex?pgcode=' + code,

						function(data) {

							$('#viewer').html("$$" + data + "$$");

							// reprocess the MathOutput Element

							MathJax.Hub.Queue([ "Typeset", MathJax.Hub,

							"viewer" ]);

						});

					}

				}

				$('#popupdiv')

						.append(

								$(

										'<div>',

										{

											id : 'warning',

											style : 'position: relative; border: solid black 1px; background-color:darkgrey;text-align: center;margin-left: auto;margin-right: auto;color: red;font-size: 24px;width: 350px;'

										}));

				$('#warning').html('Equation is too long.');

			} else {

				$('#popupdiv').css('width', equWidth + 20);

			}

		} else {

			$('#popupdiv').css('width', '530px');

		}

	};

	this.initialise = function() {

		$.each([ 'tabs', 'viewer', 'buttons' ], function(i, value) {

			$('#popupdiv').append($('<div>', {

				id : value

			})).css('background', '#f0f0f0');

		});

		$('#tabs').append($('<ul>'));

		$.each(categories, this.createCat);

		$('#viewer').html("$$ $$");

		MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "viewer" ]);

		$('#popupdiv').tabs('refresh');

		$('#popupdiv').tabs({

			selected : 0

		});

	};

	this.addTextBoxFocus = function(textBoxToFocus) {

		textBoxToFocus.focus(function() {

			me.checkTexBox($(this));

		});

	};

	this.createCat = function(i, value) {

		ul = $('#tabs > ul');

		var tabId = 'tabs-' + i;

		ul

				.append($('<li>')

						.append($('<a>', {

							href : '#' + tabId

						}).append($('<img>', {

							src : jqmv_basepath + 'img_trans.gif',

							width : "1",

							height : "1",

							border : 'none'
						}).addClass('catImg' + i)))

						.mouseenter(

								function() {

									ul

											.append($(

													'<div>',

													{

														id : 'hover',

														style : 'color:white;position: absolute; padding:2px;border: solid black 1px; background-color:#4444aa;'

													}));

									$('#hover').html(value.tooltip);

									var x;

									x = (i + 1) * (29 + 54) + 10;

									$('#hover').css({

										left : x

									});

								}).mouseleave(function() {

							$('#hover').remove();

						}));

		$('.catImg' + i).css({

			width : '54px',

			height : '36px',

		});

		$('.catImg' + i).css('background', 'url(' + value.image + ')');

		var opUl = $('<div>').css({

			padding : '0px',

		});

		var catValue = value;

		var opCount = i;

		$.each(value.operators, function(i, value) {

			var className = 'opImg' + opCount + i;

			opUl.append($('<img>', {

				src : jqmv_basepath + 'img_trans.gif',

				width : "54px",

				height : "36px"

			}).css({

				background : 'url(' + catValue.image + ') -' + i * 54 + 'px 0',

				border : 'solid 1px',

				margin : '3px'

			}).addClass(className).click(function() {

				me.generateTex(value);

			}));

			$('.' + className).css({

				width : '54px',

				height : '36px'

			});

			$('.' + className).css({

				background : 'url(' + catValue.image + ') -' + i * 54 + 'px 0'

			});

		});

		$('#tabs').append($('<div>', {

			id : tabId,

			height : "84px",

			width : "530px"

		}).append(opUl));

		$(tabId).css('height', '100px');

		opUl.addClass('classCat');

	};

	this.closeItAll = function(e) {

		if ((me.popupdiv.has(e.target).length == 0 && !me.popupdiv.is(e.target))

				&& !me.decoratedTextBox.is(e.target)) {

			me.setVisible(false);

		}

	};

	this.checkTexBox = function(decoratedTextBox) {

		if (typeof me.decoratedTextBox == 'undefined') {

			me.setTexBox(decoratedTextBox);

		} else {

			if (decoratedTextBox.attr('id') != me.decoratedTextBox.attr('id')) {

				me.setTexBox(decoratedTextBox);

			}

		}

	};

	this.setTexBox = function(decoratedTextBox) {

		$("#popupdiv").tabs({

			selected : 0

		});

		decoratedTextBox.on('keyup keypress blur change focus', function() {

			me.reGenerateTex(this.value);

		});

		decoratedTextBox.focus(function() {

			me.setVisible(true);

		});

		me.setVisible(true);

		me.decoratedTextBox = decoratedTextBox;

		me.reGenerateTex(me.decoratedTextBox.val());

		MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "viewer" ]);

		$(document).mousedown(me.closeItAll);

	};

	this.getVisibility = function() {

		return isVisible;

	};

	this.setVisible = function(value) {

		if (this.isVisible != value) {
			this.isVisible = value;

			if (this.isVisible) {
				this.popupdiv.show();

			} else {
				this.popupdiv.hide();
			}
		}

	};

	if ($('#popupdiv').length == 0) {

		$('body').append($('<div>', {

			id : 'eqEditorDiv',

			style : ' position:absolute;top:30;left:0;width: 0px; height: 0px;'

		}));

		$("#eqEditorDiv")

		.append(

		$(

		"<image id='openEqEditor' src='"

		+ jqmv_basepath

		+ "eqEditor.gif' style='visibility:hidden; max-width:100; z-index:2;'/>") 
		/* max-width protects against being clobbered by bootstrap.css matching against img max-width */

		.click(

		function() {

			if (this.isVisible) {

				popUpEquation.setVisible(false);

			} else {

				$('#equation').attr("value",

				GetSelectedText());

				popUpEquation.setVisible(true);

				$('#equation').focus();

			}

		}));

		$("#eqEditorDiv").append(

		$('<div>', {

			id : 'popupdiv',

			style : 'display: none; z-index:1;'

			+ 'position: absolute; top:20px; left:28px;'

			+ 'border: solid black 1px;' + 'padding:10px;'

			+ 'background-color:#f0f0f0;'

			+ 'text-align: justify;' + 'font-size: 12px; '

			+ 'width: 573px; height: 380px;'

		}));

		$("#popupdiv")

		.append(

		"<div id='menuEqEditor'"

		+ " style='background-color:#8888DD;"

		+ " text-align:center; font-size:22px; color:#ffffff;"

		+ " width: 100%; height: 30px; '>"+jqmv_translator[7]/*Equation Editor*/+"</div>");

		$("#popupdiv").append("<br/>");

		$("#eqEditorDiv").draggable({

			containment : "parent",

			handle : "#openEqEditor,#menuEqEditor"

		});

		$("#popupdiv").tabs();

		this.initialise();

		$("#popupdiv").append($('<input>', {

			id : 'equation',

			type : 'text',

			style : 'width:100%;'

		}));

		$("#popupdiv").append("<br/><br/>");

		$("#popupdiv").append($('<input>', {

			type : 'button',

			style : 'width:100px;height:25px; float:right;v-align:bottom;',

			value : jqmv_translator[8]/*"Insert"*/

		}).click(function() {

			replaceSelectedText();

			popUpEquation.setVisible(false);

		}));
		$("#popupdiv")
				.append(
						"<text style='float:right;'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</text>");
		this.popupdiv = $('#popupdiv');

		$("#popupdiv").append($('<input>', {

			type : 'Button',

			value : jqmv_translator[9]/*'Cancel'*/,

			id : 'eqEditClose',

			style : 'width:100px;height:25px;v-align:bottom;float:right;'

		}).click(function() {

			popUpEquation.setVisible(false);

		}));

		$("#popupdiv").append(
				$("<br/><text style='font-size:13px;'>"+jqmv_translator[6] /*Version En/FR/...*/+ Version
						+ "</text>"));
	}

}

function findPos(obj) {
	var curleft = curtop = 0;
	if (obj.offsetParent) {
		do {
			curleft += obj.offsetLeft;
			curtop += obj.offsetTop;
		} while (obj = obj.offsetParent);
	}
	return [ curleft, curtop ];
}

function GetSelectedText() {
	if (window.getSelection) { // all browsers, except IE before version 9
		var range = window.getSelection();
		return range;
	} else {
		if (document.selection.createRange) { // Internet Explorer
			var range = document.selection.createRange();
			return range;
		} else {
			return "";
		}
	}
}

function replaceSelectedText() {
	var txtarea = mathView_textzone;
	var newtxt = document.getElementById("equation").value;
	if (typeof txtarea.selectionStart != "undefined"
			&& typeof txtarea.selectionEnd != "undefined") {
		$(txtarea).val(
				$(txtarea).val().substring(0, txtarea.selectionStart) + newtxt
						+ $(txtarea).val().substring(txtarea.selectionEnd));
	} else if (typeof document.selection != "undefined"
			&& typeof document.selection.createRange != "undefined") {
		txtarea.focus();
		range = document.selection.createRange();
		range.collapse(false);
		range.text = newtxt;
		range.select();
	}
}

var popUpEquation;
$(function() {
	popUpEquation = new PopUpEquation();
	
	$.fn.addMathEditor = function() {
		var me = this.filter(function(index) {
			return $(this).is('input[type="text"]') || $(this).is('textarea');
		});
		popUpEquation.addTextBoxFocus(me);

		return me;

	};
	$.fn.addMathEditorButton = function(rendering) {
		mathView_textzone = this;
		mathView_textzone.focus(function() {
			if (typeof rendering != "undefined") {
				if (rendering != "PGML" && rendering != "LATEX") {
					alert("The value :\"" + rendering
							+ "\". The only admissible values are PGML or LATEX");
					return;
				}
				popUpEquation.renderingMode = rendering;
			}
			mathView_textzone = this;
			var mathEditorIcon = document.getElementById("openEqEditor");
			var mathEditorDiv = document.getElementById("eqEditorDiv");
			var pos = findPos(mathView_textzone);
			var textZoneX = pos[0];
			var textZoneY = pos[1];
			var iconNewX;
			var iconNewY;
			if ($(this).is('input')) {
				iconNewX = textZoneX + 2 + $(mathView_textzone).width() + "px";
				iconNewY = textZoneY - 5 + "px";
			} else {
				iconNewX = textZoneX + 3 + $(mathView_textzone).width() + "px";
				iconNewY = textZoneY - 0 + "px";
			}
			if (mathEditorIcon.style.visibility == "hidden") {
				mathEditorIcon.style.visibility = "visible";
			}
			mathEditorDiv.style.position = "absolute";
			mathEditorDiv.style.left = iconNewX;
			mathEditorDiv.style.top = iconNewY;
		});
	};
	$.fn.insertAtCaret = function(myValue) {
		return this
				.each(function() {
					var me = this;
					if (document.selection) { // Internet Explorer
						me.focus();
						sel = document.selection.createRange();
						sel.text = myValue;
						me.focus();
					} else if (me.selectionStart || me.selectionStart == '0') { // Others browsers
						var startPos = me.selectionStart, endPos = me.selectionEnd, scrollTop = me.scrollTop;
						me.value = me.value.substring(0, startPos) + myValue
						+ me.value.substring(endPos, me.value.length);
						me.focus();
						me.selectionStart = startPos + myValue.length;
						me.selectionEnd = startPos + myValue.length;
						me.scrollTop = scrollTop;
					} else {
						me.value += myValue;
						me.focus();
					}
				});
	};
});
