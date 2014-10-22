$(function(){

    // Turn submit inputs into buttons
    $('input:submit').addClass('btn btn-primary');
    $('.nav_button').addClass('btn btn-primary');
    $('.classlist').addClass('table table-condensed classlist-table');

    // Try to format checkboxes better
    $('input:checkbox').parent('label').addClass('checkbox');
    $('input:radio').parent('label').addClass('radio');

    // Make grey_buttons disabled buttons
    $('.gray_button').addClass('btn disabled').removeClass('gray_button');
    
    // Make grey_buttons disabled buttons
    $('.gray_button').addClass('btn disabled').removeClass('gray_button');

    // replace pencil gifs by something prettier
    $('td a:has(img[src$="edit.gif"])').each(function () { $(this).html($(this).html().replace(/<img.*>/," <i class='icon-pencil'></i>")); });
    $('img[src$="question_mark.png"]').replaceWith('<i class="icon-question-sign" style="font-size:16px; margin-right:5px"/>');

    // Turn summaries into popovers
    $('a.table-summary').popover();

    // Sets login form input to bigger size
    $('#login_form input').addClass('input-large');
    
    // Changes links in masthead
    $('#loginstatus a').addClass('btn btn-small');
    $('#loginstatus a').append(' <i class="icon-signout"></i>');
    
    // Changes edit links in info panels to buttons
    $("#info-panel-right a:contains('[edit]')").addClass('btn btn-small btn-info');
    $("#info-panel-right a:contains('[edit]')").text('Edit');

    // Add a button to make the sidebar more dynamic for small screens
    $('#toggle-sidebar').removeClass('btn-primary').click(function (event) {
	    event.preventDefault();
	    $('#site-navigation').toggleClass('hidden');
	    $('#toggle-sidebar-icon').toggleClass('icon-chevron-left').toggleClass('icon-chevron-right');
	    $('#site-navigation').toggleClass('span2');
	    $('#content').toggleClass('span10').toggleClass('span12').toggleClass('fix-content-margin');
	});
	
	var ANSM = {};
	ANSM.threshold = 768;
	ANSM.windowwidth = $(window).width();
	ANSM.ltthreshold = (ANSM.windowwidth < ANSM.threshold) ? 1 : 0;
	//Initial settings for sidemenu
    if(ANSM.ltthreshold) {
		$('#toggle-sidebar').click();
    }	
	
	$(window).resize(function(){
		ANSM.windowwidth = $(window).width();
		if(ANSM.windowwidth < ANSM.threshold && !ANSM.ltthreshold){
			$('#site-navigation').addClass('hidden');	
			$('#masthead').addClass('span12');
	    	$('#toggle-sidebar-icon').addClass('icon-chevron-left').removeClass('icon-chevron-right');	
	    	$('#site-navigation').removeClass('span2');	
	    	$('#content').removeClass('span10').addClass('span12').addClass('fix-content-margin');
			ANSM.ltthreshold = 1;
		}else if(ANSM.windowwidth >= ANSM.threshold && ANSM.ltthreshold){	
			$('#site-navigation').removeClass('hidden'); 
			$('#masthead').removeClass('span12');
	    	$('#toggle-sidebar-icon').removeClass('icon-chevron-left').addClass('icon-chevron-right');		
			$('#site-navigation').addClass('span2');
			$('#content').addClass('span10').removeClass('span12').removeClass('fix-content-margin');
			ANSM.ltthreshold = 0;	
		}
	});

    // if no fish eye then collapse site-navigation 
    if($('#site-links').length > 0 && !$('#site-links').html().match(/[^\s]/)) {
	$('#site-navigation').removeClass('span2');
	$('#content').removeClass('span10').addClass('span11');
	$('#toggle-sidebar').addClass('hidden');
    }

    // Makes the fisheye stuff bootstrap nav
    $('#site-navigation ul').addClass('nav nav-list');
    $('#site-navigation li').each(function () { $(this).html($(this).html().replace(/<br>/g,"</li><li>")); });
    $('#site-navigation a.active').parent().addClass('active');
    $('#site-navigation strong.active').parent().addClass('active');
    $('#site-navigation li').find('br').remove();

    // Display options formatting
    $('.viewOptions label:has(input:radio)').addClass('radio');
    $('label.radio').nextUntil(':not(br)').remove();
    $('.viewOptions input:submit').addClass('btn-small');
    $('.facebookbox input:submit').addClass('btn-small');

    //Reformats the problem_set_table.  
    $('#problem-sets-form').addClass('form-inline');
    $('.body:has(.problem_set_table)').addClass('problem_set_body');
    $('.problem_set_table').addClass('table');
    if($('.problem_set_table th:contains("Test Score")').length > 0) {
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

    $("table.attemptResults td[onmouseover*='Tip']").each(function () {
	var data = $(this).attr('onmouseover').match(/Tip\('(.*)'/);
	if (data) { data = data[1] }; // not sure I understand this, but sometimes the match fails 
	//on the presentation of a matrix  and then causes errors throughout the rest of the script
	$(this).attr('onmouseover','');
	if (data) {
	    $(this).wrapInner('<div class="results-popover" />');

	    var popdiv = $('div', this);
	    popdiv.popover({placement:'bottom', html:'true', trigger:'click',content:data});	
	} 
	    
    });
    
    // Grades formatting
    $('#grades_table').addClass('table table-bordered table-condensed');

    //Problem Grader formatting
    $('#problem-grader-form').addClass('form-inline');
    $('#problem-grader-form input:button').addClass('btn btn-small');
    $('#problem-grader-form td').find('p:last').removeClass('essay-answer graded-answer');

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
    $('#editor div').each(function () { $(this).html($(this).html().replace(/\|/g,"")); });
    $('#editor label[class="radio"]').after('<br/>');

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
    $('#send-mail-form input[value="Send Email"]').addClass('btn-primary');

    //Score sets
    $('#scoring-form').addClass('form-inline');
    $('#scoring-form input:submit').addClass('btn-small');

    //Student progress and statistics
    $('table.progress-table').addClass('table table-bordered table-condensed');
    $('table.stats-table').addClass('table table-bordered');
    $('#sp-gateway-form').addClass('well');

    //Library browser 1 tweaks
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
});    

