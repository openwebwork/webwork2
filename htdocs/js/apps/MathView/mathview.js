// Class constructor
// Create the equation editor decorator around the decoratedTextBox and 
// generate PGML or LaTeX code depending ont the renderingMode option.
// params:
//    decoratedTextBox: the text box being decorated this is now always defined using the 
//                      class constructor
//    rederingMode: Either "PGML" to render PGML code or "LATEX" to render LaTeX code.

// Note: This version has been forked from the 1.1.0 mathveiw release and is now WeBWorK specific

var mathView_version = "1.2.0";
var mathView_basepath;

/* Makes escape key hide any visible popups */
$(document).keydown(function(e){
    if (e.keyCode === 27)
	$('.popover').hide();
});

/* load up and config mathview */
$(document).ready(function() {

    MathJax.Hub.Register.StartupHook('AsciiMath Jax Config', function () {
	var AM = MathJax.InputJax.AsciiMath.AM;
	for (var i=0; i< AM.symbols.length; i++) {
	    if (AM.symbols[i].input == '**') {
		AM.symbols[i] = {input:"**", tag:"msup", output:"^", tex:null, ttype: AM.TOKEN.INFIX};
	    }
	}
    });
    /* Make sure mathjax is confugued for AsciiMath input */
    MathJax.Hub.Config(["input/Tex","input/AsciiMath","output/HTML-CSS"]);

    /* attach a viewer to each input */
    $('.codeshard').each(function () {
	var input = this;
	var mviewer = new MathViewer(input);
	mviewer.initialize();
	/* create button and attach it to side of input */
	$(input).wrap('<div class="input-append" />')
	    .css('margin-right', '0px');

	/* set button behavior.  It closes all other popovers and opens this inputs popover when clicked */
	var button = $('<a>', {href : '#', class : 'btn codeshard-btn', style : 'margin-right : .5ex'})
	    .html('<i class="icon-th"></i>')
	    .click(function () {
		var current = this;
		
		$('.codeshard').each(function () {
		    var others = $(this).siblings('a')[0];
		    if (others != current) {
			$(others).popover('hide');
		    }
		});

		$(current).popover('toggle');
		$('.popover').draggable({handle: ".brand"});
		$(this).siblings('input').keyup();
		MathJax.Hub.Queue([ "Typeset", MathJax.Hub]);

		return false;
	    });

	/* actually initialize the popover */
	$(button).popover({html : 'true',
			 content : mviewer.popoverContent,
			 trigger : 'manual',
			 placement : 'right',
			 title : mviewer.popoverTitle,
			 container : '.problem-content'
		     }); 
	$(input).parent().append(button);
	/* make sure popover refreshes math when there is a keyup in the input */
	$(input).keyup(mviewer.regenPreview);
	$(input).focus(function () {
	    var current = $(this).siblings('a')[0];
	    
	    $('.codeshard').each(function () {
		var others = $(this).siblings('a')[0];
		if (others != current) {
		    $(others).popover('hide');
		}
	    });
	    
	});
	    
    });
    
});

function MathViewer(field) {

    /* Always render using PGML.  Latex mode is vestigal */
    this.renderingMode = "PGML";

    /* give a unique index to this instance of the viewer */
    if (typeof MathViewer.viewerCount == 'undefined' ) {
	MathViewer.viewerCount = 0;
    }
    MathViewer.viewerCount++;
    var viewerIndex = MathViewer.viewerCount;
    var me = this;
    this.decoratedTextBox = $(field);

    MathJax.Hub.Config({
	showProcessingMessages : false,
	TeX : {MultLineWidth : "50%"},
    });
    
    /* start setting up html elements */
    var popupdiv;
    var popupttl;
    var dropdown;
    var tabContent;

    /* initialization function does heavy lifting of generating html */
    this.initialize = function() {
		
	/* start setting up html elements */
	popupdiv = $('<div>', {class : 'popupdiv'});
	popupttl = $('<div>', {class : 'navbar'});
	dropdown = $('<ul>', {class : 'dropdown-menu'});
	tabContent = $('<div>', {class : 'tab-content'});

	/* generate html for each of the categories in the locale file */
	$.each(mv_categories, this.createCat);

	/* create the title bar with dropdown menue and move/close buttons */
	popupttl.append($('<div>', {class : 'navbar-inner'})
			.append('<a class="brand" href="#">'+mathView_translator[7]/*Equation Editor*/+'</a>')
			.append($('<ul>', {class : "nav"})
				.append($('<li>', {class : "dropdown"})
					.append('<a href="#" class="dropdown-toggle" data-toggle="dropdown">'
						+'Operations <b class="caret"></b></a>')
					.append(dropdown)))
			.append($('<ul>', {class : "nav pull-right"})
				.append($('<li>')
					.append('<a href="#" onclick="$(' + "'.codeshard-btn').popover('hide')" + 
						'; return false;"><i class="icon-remove"></i></a>'))));
	/* put the categories content into the main popop div, 
	   activate the tabs, 
	   and put the preview div in place 
	*/

	popupdiv.append(tabContent);
	
	dropdown.find('a:first').tab('show');
	tabContent.find('.tab-pane:first').addClass('active');

	popupdiv.append($('<div>', {class : 'well well-small mviewerouter'})
			.append($('<p>', {id : 'mviewer'+viewerIndex, class : 'mviewer'})
				.html('`'+me.decoratedTextBox.val()+'`')));
	
	/* set up the autocomplete feature */
	this.createAutocomplete();
	
    }	

    /* This function inserts the appropriate string into the 
       input box when a button in the viewer is pressed */

    this.generateTex = function(strucValue) {
	var pos = me.decoratedTextBox.getCaretPos();
	var newpos = pos;

	if (me.renderingMode == "LATEX") {
	    me.decoratedTextBox.insertAtCaret(strucValue.latex);
	    var parmatch = strucValue.latex.match(/\(\)/);
	    if (parmatch) {
		newpos += parmatch[0].index;
	    }
	    me.decoratedTextBox.setCaretPos(newpos);
	    me.decoratedTextBox.keyup();
	} else if (me.renderingMode == "PGML") {
	    me.decoratedTextBox.insertAtCaret(strucValue.PG);
	    var parmatch = strucValue.PG.match(/\(\)/);
	    if (parmatch) {
		newpos += parmatch.index+1;
	    }
	    me.decoratedTextBox.setCaretPos(newpos);
	    me.decoratedTextBox.keyup();
	} else
	    console.log('Invalid Rendering Mode');
    }
    
    /* this function regenerates the preview in the math viewer
       whenever the input value changes */
    
    this.regenPreview = function() {
	var text = me.decoratedTextBox.val();

	if (me.renderingMode == "LATEX") {
	    $('#mviewer'+viewerIndex).html("\(" + text + "\)");
	    MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "mviewer"+viewerIndex ]);
	} else if (me.renderingMode == "PGML") {
		$('#mviewer'+viewerIndex).html("`" + text + "`");
		MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "mviewer"+viewerIndex ]);
	} else
	    console.log('Invalid Rendering Mode');
    };
    
    /* this function returns the html for the body of the math viewer */

    this.popoverContent = function() {
	me.initialize();
	return popupdiv;
	
    };

    /* this function returns the html for the title of the math viewer */

    this.popoverTitle = function () {
	return popupttl;
    };

    /* this function creates a category from the locale js.  
       each category is implemented using bootstraps tab feature. 
       The selectors for the tab go in a dropdown menu.  The tabs contain
       a thumbnail grid of the buttons in the category
    */

    this.createCat = function(catCount, catValue) {
	var thisTabList = $('<ul>', {class : 'thumbnails'});
	
	$.each(catValue.operators, function(i, value) {
	    
	    var className = 'opImg' + catCount + i;
	    /* creates a li for each operator/button in the category */
	    thisTabList.append($('<li>', {class : 'span3'})
			       .append($('<a>', {class : 'thumbnail text-center'})
				       .append(value.text)
				       .tooltip({trigger : 'hover',
						 delay : {show :500, hide:100},
						 title : value.tooltip
						})
				       .addClass(className).click(function() {
					   me.generateTex(value);
				       })));
	});
	
	/* create acutal tab pane for category and add entry to list*/
	tabContent.append($('<div>', {class : 'tab-pane', 
				      id : 'mvtab'+viewerIndex+catCount})
			  .append(thisTabList));
	
	dropdown.append($('<li>')
			.append($('<a>', {href : '#mvtab'+viewerIndex+catCount,
					  'data-toggle' : 'tab'})
				.append(catValue.text)));
    };
   
    /* enables an autocomplete feature for the input */
    this.createAutocomplete = function  () {
	var source = [];
	
	/* get autocomplete functions and put into list */
	$.each(mv_categories, function (cati, catval) {
	    $.each(catval.operators, function (i, val) {
		    if (val.autocomp) {
			source.push(val.PG);
		    }
	    });
	});
	
	
	/* implement autocomplete feature using bootstrap typeahead */
	$(me.decoratedTextBox).attr('autocomplete', 'off')
	    .typeahead({source: source,
			minLength : 0,
			/* the matcher function tries to strip off all of the parts
			   of the equation before and after the cursor position that
			   are not a-z and compares to item */
			matcher: function (item) {
			    var len = this.query.length;
			    var pos = me.decoratedTextBox.getCaretPos();
			    var re = new RegExp('[a-z]*.{'+(len-pos)+'}$');
			    var query = this.query;
			    var match = query.match(re);
			    if (!match) 
				return false;
			    query = match[0];
			    re = new RegExp('^.{'+(pos-(len-query.length))+'}[a-z]*');
			    match = query.match(re);
			    if (!match) 
				return false;
			    query = match[0];
			    if (query.length < 1) 
				return false;
			    re = new RegExp('^'+query);
			    item = item.replace(/\(\)/,'');

			    /* dont display popup if we are done typing function */
			    if (item == query+'(') {
				return false;
			    }

			    match = item.match(re);
			    if (match) {
				return true;
			    }
			    return false;
			},
			/* this function actually generates the new string
			   to be put into the input.  It inserts the full function
			   at the cursor position */
			updater : function (item) {
			    var len = this.query.length;
			    var pos = me.decoratedTextBox.getCaretPos();
			    var newpos = pos;
			    var re = new RegExp('[a-z]*.{'+(len-pos)+'}$');
			    var query = this.query;
			    var query = query.match(re)[0];
			    re = new RegExp('^.{'+(pos-(len-query.length))+'}[a-z]*');
			    query = query.match(re)[0];
			    var parmatch = item.match(/\(\)/);
			    if (parmatch) {
				newpos += parmatch.index+1;
			    } else {
				newpos += item.length;
			    }
			    newpos -= query.length;
			    item = item.replace(query,'');
			    me.decoratedTextBox.change(function () {
				me.decoratedTextBox.setCaretPos(newpos);
				me.decoratedTextBox.off('change');
			    });
			    
			    return [this.query.slice(0,pos), 
				    item, 
				    this.query.slice(pos)].join('');
			}
		       });
	
	/* this overrides a broken part of bootstrap */
	$(me.decoratedTextBox).data('typeahead').move = function (e) {
	    if (!this.shown) return;
	    
	    if (e.type === 'keypress') return; //40 and 38 are characters in a keypress
	    
	    switch(e.keyCode) {
	    case 9: // tab
	    case 13: // enter
	    case 27: // escape
		e.preventDefault()
		break
		
	    case 38: // up arrow
		e.preventDefault()
		this.prev()
		break
		
	    case 40: // down arrow
		e.preventDefault()
		this.next()
		break
	    }
	    e.stopPropagation();
	    
	}
	
    };

}

$(function () {

    /* this is a function I found on the internet to isnert text at a the cursor 
       position in a text box */

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
		    var startPos = me.selectionStart;
		    endPos = me.selectionEnd; 
		    var scrollTop = me.scrollTop;
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

    /* this is a function I found on the internet to find the position of a cursor
       in the text box */

    $.fn.getCaretPos = function () {
	var input = this.get(0);
        if (!input) return; // No (input) element found
        if ('selectionStart' in input) {
            // Standard-compliant browsers
            return input.selectionStart;
        } else if (document.selection) {
            // IE
            input.focus();
            var sel = document.selection.createRange();
            var selLen = document.selection.createRange().text.length;
            sel.moveStart('character', -input.value.length);
            return sel.text.length - selLen;
        }
    };
    
    /* this is a function i found on the enternet to set the position of a cursor
       in the text box */
    
    $.fn.setCaretPos = function(pos)   {
	var obj=this.get(0);
	
	//FOR IE
	if(obj.setSelectionRange)
	{
            obj.focus();
            obj.setSelectionRange(pos,pos);
	}
	
	// For Firefox
	else if (obj.createTextRange)
	{
            var range = obj.createTextRange();
            range.collapse(true);
            range.moveEnd('character', pos);
            range.moveStart('character', pos);
            range.select();
	}
    }
    
});