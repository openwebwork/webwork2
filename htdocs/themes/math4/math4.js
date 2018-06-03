// Object for toggling the sidebar
var ToggleNavigation = function () {
    var threshold = 768
    var windowwidth = $(window).width();
    var navigation_element = $('#site-navigation');
    
    var hideSidebar = function () {
	$('#site-navigation').remove();
	$('#toggle-sidebar-icon').removeClass('icon-chevron-left').addClass('icon-chevron-right');	
	$('#content').removeClass('span10').addClass('span11');
    }

    var showSidebar = function () {
	$('#body-row').prepend(navigation_element);
	$('#toggle-sidebar-icon').addClass('icon-chevron-left').removeClass('icon-chevron-right');
	$('#content').addClass('span10').removeClass('span11');	
    }

    var toggleSidebar = function () {
	if ($('#toggle-sidebar-icon').hasClass('icon-chevron-left')) {
	    hideSidebar();
	} else {
	    showSidebar();
	}
    }
        
    // if no fish eye then collapse site-navigation 
    if($('#site-links').length > 0 && !$('#site-links').html().match(/[^\s]/)) {
	$('#site-navigation').remove();
	$('#content').removeClass('span10').addClass('span11');
	$('#toggle-sidebar').addClass('hidden');
	$('#breadcrumb-navigation').width('100%');
    } else {
	// otherwise enable site-navigation toggling
	if (windowwidth < threshold) {
	    hideSidebar();
	}
	    
	$('#toggle-sidebar').click(function (event) {
	    event.preventDefault();
	    toggleSidebar();
	});
	
	
	$(window).resize(function(){
	    if ($(window).width() != windowwidth) {
		windowwidth = $(window).width();
		if(windowwidth < threshold && $('#toggle-sidebar-icon').hasClass('icon-chevron-left')) {
		    hideSidebar();
		} else if (windowwidth >= threshold && $('#toggle-sidebar-icon').hasClass('icon-chevron-right')) {	
		    showSidebar();
		}
	    }
	}); 
    }
}

$(function(){
    // Initialize navigation menu toggling
    ToggleNavigation();
    
    // Focus on a  results with error if one is around and focussable. 
    $('.ResultsWithError').first().focus();

    // Fix bug with skip to main content link in chrome
    $('#stmc-link').click(function() {
	$('#page-title').attr('tabIndex', -1).focus();
    });

    // Turn submit inputs into buttons
    $('input:submit').addClass('btn btn-primary');
    $('input:submit').mousedown(function () {this.blur(); return false;});
    $('.nav_button').addClass('btn btn-primary');
    $('.classlist').addClass('table table-condensed classlist-table');

    // Try to format checkboxes better
    $('input:checkbox').parent('label').addClass('checkbox');
    $('input:radio').parent('label').addClass('radio');

    // Make grey_buttons disabled buttons
    $('.gray_button').addClass('btn disabled').removeClass('gray_button');

    // replace pencil gifs by something prettier
    $('td a:has(img[src$="edit.gif"])').each(function () { $(this).html($(this).html().replace(/<img.*>/," <span class='icon icon-pencil' data-alt='edit'></span>")); });
    $('img[src$="question_mark.png"]').replaceWith('<span class="icon icon-question-sign" data-alt="help" style="font-size:16px; margin-right:5px"></span>');

    // Turn summaries and help boxes into popovers
    // Not sure there are any table-summary classes
    // loading Sage interacts removes the popover function 
    //(loads older version of bootstrap?)
    // so we'll work around that for now
    if ($.fn.popover) {
    	$('a.table-summary').popover({trigger : 'click'}).click(function (event) {
		event.preventDefault();
		});
		$('a.help-popup').popover({trigger : 'click'}).click(function (event) {
		event.preventDefault();
		}).html('<i class="icon-question-sign"/><span class="sr-only">Help Icon</span>');
    }
    // Sets login form input to bigger size
    $('#login_form input').addClass('input-large');    
    
    // Changes edit links in info panels to buttons
    var editButton = $("#info-panel-right h2:first a:first")
    editButton.addClass('btn btn-small btn-info');
    editButton.text(editButton.text().replace(/\[([^\]].*)\]/, '$1'));

    //Problem page
    $('.currentProblem').addClass('active');

    //Reformats the problem_set_table.  
    $('#problem-sets-form').addClass('form-inline');
    $('.body:has(.problem_set_table)').addClass('problem_set_body');
    $('.problem_set_table').addClass('table');
    if($('.problem_set_table').find("tr:first th").length > 3) {
	$('.problem_set_table').addClass('small-table-text');
    }

    $('#hardcopy-form').addClass('form-inline');

    $('.problem_set_options input').addClass('btn btn-info');
    $('.problem_set_options a').addClass('btn btn-info');

    // Problem formatting
    $('#problemMainForm').addClass('problem-main-form form-inline');
    $('.attemptResults').addClass('table table-condensed table-bordered');
    $('.problem .problem-content').addClass('well well-small');
    $('.answerComments').addClass('well');
    $('#SMA_button').addClass('btn btn-primary');
    

    // this finds the wztooltips object entries and adds
    // bootstrap styling using popover to them
    // check first that popover is defined 
    // (work around for sage interacts which remove popover for some reason)
	$("table.attemptResults td[onmouseover*='Tip']").each(function(index,elem) {
		var data = $(this).attr('onmouseover').match(/Tip\('(.*)'/);	
		if (data) { data = data[1] }; // not sure I understand this, but sometimes the match fails 
		//on the presentation of a matrix  and then causes errors throughout the rest of the script
		if ($.fn.popover) { 
			$(this).attr('onmouseover','');
			if (data) {
				$(this).wrapInner('<div class="results-popover" />');
				var popdiv = $('div', this);
				popdiv.popover({placement:'bottom', html:'true', trigger:'click',content:data});	
			}
		} 
	    
	});

    // sets up problems to rescale the image accoring to attr height width
    // and not native height width.  
    var rescaleImage = function (index,element) {
	if ($(element).attr('height') != $(element).get(0).naturalHeight || 
	$(element).attr('width') != $(element).get(0).naturalWidth) {
	    $(element).height($(element).width()*$(element).attr('height')
			   /$(element).attr('width'));
	}
    }
    
    $('.problem-content img').each(rescaleImage);

    $(window).resize(function () {
	$('.problem-content img').each(rescaleImage);
    });
    
    // Grades formatting
    $('#grades_table').addClass('table table-bordered table-condensed');
    $('.additional-scoring-msg').addClass('well');
    
    //Problem Grader formatting
    $('#problem-grader-form').addClass('form-inline');
    $('#problem-grader-form input:button').addClass('btn btn-small');
    $('#problem-grader-form td').find('p:last').removeClass('essay-answer graded-answer');
    $('#problem-grader-form .score-selector').addClass('input-min');

    //CourseConfiguration
    $('#config-form').addClass('form-inline');
    $('#config-form table').addClass('table table-bordered');

    //Instructor Tools
    $('#instructor-tools-form input').removeClass('btn-primary');

    //File Manager Configuration
    $('#FileManager').addClass('form-inline');
    $('#FileManager .btn').addClass('btn-small file-manager-btn').removeClass('btn-primary');
    $('#FileManager #Upload').addClass('btn-primary');
    
    //Classlist Editor 1&2 configuration
    $('#classlist-form').addClass('form-inline user-list-form');
    $('.user-list-form input:button').addClass('btn btn-info');
    $('.user-list-form input:reset').addClass('btn btn-info');
    $('.user-list-form').wrapInner('<div />');
    $('.classlist-table').addClass('table table-condensed table-bordered');
    $('.classlist-table').attr('border',0);
    $('.classlist-table').attr('cellpadding',0);
    $('#show_hide').addClass('btn btn-info');
    $('#new-users-form table').addClass('table table-condensed');
    $('#new-users-form .section-input, #new-users-form .recitation-input').attr('size','4');
    $('#new-users-form .last-name-input, #new-users-form .first-name-input, #new-users-form .user-id-input').attr('size','10');

    //Homework sets editor config
    $('#problemsetlist').addClass('form-inline set-list-form');
    $('#problemsetlist2').addClass('form-inline set-list-form');
    $('#edit_form_id').addClass('form-inline set-list-form');
    $('.set-id-tooltip').tooltip({trigger: 'hover'});
    $('.set-list-form input:button').addClass('btn btn-info');
    $('.set-list-form input:reset').addClass('btn btn-info');
    $('.set-list-form').wrapInner('<div />');
    $('.set_table').addClass('small-table-text table-bordered table table-condensed');
    $('#show_hide').addClass('btn btn-info');
    $('#problem_set_form').addClass('form-inline');
    $('#user-set-form').addClass('form-inline user-assign-form');
    $('#set-user-form').addClass('form-inline user-assign-form');
    $('.set_table input[name="selected_sets"]').each(function () {
	var label = $(this).parent().children('label');
	label.prepend(this);
	label.addClass('checkbox');
    });
    $('#problem_set_form input[name="refresh"]').removeClass("btn-primary");
    
    //PG editor styling
    $('#editor').addClass('form-inline span9');
    $('#editor a').addClass('btn btn-small btn-info');
    $('#editor > div').each(function () { $(this).html($(this).html().replace(/\|/g,"")); });

    //Achievement Editor
    $('#achievement-list').addClass('form-inline user-list-form');
    $('.user-list-form input:button').addClass('btn btn-info');
    $('.user-list-form input:reset').addClass('btn btn-info');
    $('.user-list-form').wrapInner('<div />');
    $('#show_hide').addClass('btn btn-info');
    $('#user-achievement-form').addClass('form-inline user-assign-form');

    //email page
    $('#send-mail-form').addClass('form-inline');
    $('#send-mail-form .btn').addClass('btn-small').removeClass('btn-primary');
    $('#send-mail-form #sendEmail_id').addClass('btn-primary');

    //Score sets
    $('#scoring-form').addClass('form-inline');
    $('#scoring-form input:submit').addClass('btn-small');

    //Student progress and statistics
    $('table.progress-table').addClass('table table-bordered table-condensed');
    $('table.stats-table').addClass('table table-bordered');
    $('#sp-gateway-form').addClass('well');

    //Library browser tweaks
    $('#mainform ').addClass('form-inline');
    $('#mainform input:button').addClass('btn btn-primary');
    $('#mainform input[type="submit"]').removeClass('btn-primary');
    $('#mainform input[name="edit_local"]').addClass('btn-primary');    
    $('#mainform input[name="new_local_set"]').addClass('btn-primary');
    $('#mainform .btn').addClass('btn-small');
    $('#mainform .InfoPanel select').addClass('input-xxlarge');
    $('#mainform select[name=mydisplayMode]').addClass('input-small').removeClass('input-xxlarge');
    $('#mainform select[name=local_sets]').addClass('input').removeClass('input-xxlarge');
    $('#mainform select[name=max_shown]').addClass('input-small').removeClass('input-xxlarge');

    //Library browser nojs tweaks
    $('.library-browser-table-nojs label.checkbox').css('display','inline-block');

    //Change tabber tabs to twitter tabs
    if ($('div.tabber').length > 0) {tabberAutomatic({});}
    $('ul.tabbernav').removeClass('tabbernav').addClass('old-tabber nav nav-tabs');
    $('ul.old-tabber li a').each(function () { $(this).attr('href','#'+$(this).attr('title').replace(/\s+/g, '')).attr('data-toggle','tab');});
    $('div.tabberlive').removeClass('tabberlive').addClass('tab-content');
    $('div.tabbertab').each(function() { $(this).removeClass('tabbertab').addClass('tab-pane').attr('id',$(this).find('h3').html().replace(/\s+/g,''))});
    $('div.tab-pane h3').remove();
    if ($('li.tabberactive a').length > 0) { 
        $('li.tabberactive a').tab('show');}

    //past answer table
    $('.past-answer-table').addClass("table table-striped");
    $('#past-answer-form').addClass("form-inline");

     //GatewayQuiz
    $('.gwPrintMe a').addClass('btn btn-info');
    $('.gwPreview a').addClass('btn');


    // the datepicker uses addOnLoadEvent, so if this function isn't defined,
    // we dont have to worry about the datepicker.
    if (typeof(addOnLoadEvent) === 'function') {
	addOnLoadEvent( function () {
	    $('.ui-datepicker-trigger').addClass('btn').parent().addClass('input-append');
	});
    }

    /* For accessibility we need to change single answer aria labels to 
       "answer" and not "answer 1" */
    if ($('.codeshard').length == 1) {
	$('.codeshard').attr('aria-label','answer');
    }

    /* Glyphicon accessibility */
    jQuery('span.icon').each(function() {
        /*
	 * The glyphicon needs to be formatted as follows.
	 * <span class="icon icon-close" data-alt="close"></span>
	 *
	 * The script takes the contents of the data-alt attribute and presents it as alternative content for screen reader users.
	 *
	 */
        $(this).attr('aria-hidden', 'true'); // hide the pseudo-element from screen readers
        var alt = jQuery(this).data('alt') // get the data-alt attribute
        var textSize = jQuery(this).css('font-size'); // get the font size of the glyphicon
        // if the data-alt attribute exists, write the contents of the attributwe
        if (typeof alt !== "undefined") {
            // if the glyphicon font is loaded, write the contents of the data-alt to off-screen screen reader only text
            // and size the "hidden" text to be the same size as the glyphicon
            if ($(this).css('font-family') == 'FontAwesome') {
                $(this).after('<span style="font-size:'+ textSize +'" class="sr-only-glyphicon">' + alt + '</span>');

            } else { // if the glyphicon font is NOT loaded, write the contents of the data-alt to on-screen text because the font is not displaying correctly
                $(this).after('<span>' + alt + '</span>');
                $(this).addClass('sr-only'); // make the failing glyphicon hidden off screen so it will not confuse users
            }
        }
    });
    
});    

