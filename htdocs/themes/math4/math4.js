// Handle some bootstrap/jquery-ui conflicts.
if ($.widget) {
	$.widget.bridge('uibutton', $.ui.button);
	$.widget.bridge('uitooltip', $.ui.tooltip);
}
if ($.fn.button.noConflict) $.fn.bootstrapBtn = $.fn.button.noConflict();

(function() {
	// Initialize navigation menu toggling
	var threshold = 768
	var windowwidth = $(window).width();
	var navigation_element = $('#site-navigation');

	var hideSidebar = function () {
		$('#site-navigation').remove();
		$('#toggle-sidebar-icon i').removeClass('fa-chevron-left').addClass('fa-chevron-right');
		$('#content').removeClass('span10').addClass('span11');
	};

	var showSidebar = function () {
		$('#body-row').prepend(navigation_element);
		$('#toggle-sidebar-icon i').addClass('fa-chevron-left').removeClass('fa-chevron-right');
		$('#content').addClass('span10').removeClass('span11');	
	};

	var toggleSidebar = function () {
		if ($('#toggle-sidebar-icon i').hasClass('fa-chevron-left')) {
			hideSidebar();
		} else {
			showSidebar();
		}
	};

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
				if(windowwidth < threshold && $('#toggle-sidebar-icon i').hasClass('fa-chevron-left')) {
					hideSidebar();
				} else if (windowwidth >= threshold && $('#toggle-sidebar-icon i').hasClass('fa-chevron-right')) {
					showSidebar();
				}
			}
		}); 
	}

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

	// Turn help boxes into popovers
	if ($.fn.popover) {
		$('a.help-popup').popover({trigger : 'hover'}).click(function (e) { e.preventDefault(); });
	}
	// Sets login form input to bigger size
	$('#login_form input').addClass('input-large');

	// Changes edit links in info panels to buttons
	var editButton = $("#info-panel-right h2:first a:first")
	editButton.addClass('btn btn-small btn-info');
	editButton.text(editButton.text().replace(/\[([^\]].*)\]/, '$1'));

	//Problem page
	$('.currentProblem').addClass('active');

	$('.student-nav-button').tooltip({trigger: 'hover'});

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
	$('#problemMainForm, form[name=gwquiz]').addClass('problem-main-form form-inline');
	$('.attemptResults').addClass('table table-condensed table-bordered');
	$('.problem .problem-content').addClass('well well-small');
	$('.answerComments').addClass('well');
	$('#SMA_button').addClass('btn btn-primary');

	// Set up popovers in the attemptResults table.
	if ($.fn.popover) { $("table.attemptResults td span.answer-preview").popover({ trigger: 'click' }); }

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
	$('#problem_set_form').addClass('form-inline');
	$('#user-set-form').addClass('form-inline user-assign-form');
	$('#set-user-form').addClass('form-inline user-assign-form');
	$('.set_table input[name="selected_sets"]').each(function () {
		var label = $(this).parent().children('label');
		label.prepend(this);
		label.addClass('checkbox');
	});
	$('#problem_set_form input[name="refresh"]').removeClass("btn-primary");

	//PG Problem Editor
	$('.reference-link').tooltip();

	//Achievement Editor
	$('#achievement-list').addClass('form-inline user-list-form');
	$('.user-list-form input:button').addClass('btn btn-info');
	$('.user-list-form input:reset').addClass('btn btn-info');
	$('.user-list-form').wrapInner('<div />');
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

	/* For accessibility we need to change single answer aria labels to 
	   "answer" and not "answer 1" */
	if ($('.codeshard').length == 1) {
		$('.codeshard').attr('aria-label','answer');
	}

	// Accessibility
	// Present the contents of the data-alt attribute as alternative content for screen reader users.
	// The icon should be formatted as <i class="icon fas fa-close" data-alt="close"></i>
	jQuery('i.icon').each(function() {
		var alt = jQuery(this).data('alt')
		if (typeof alt !== "undefined") {
			var textSize = jQuery(this).css('font-size'); // Get the font size of the icon.
			$(this).after('<span style="font-size:'+ textSize +'" class="sr-only-glyphicon">' + alt + '</span>');
		}
	});
})();
