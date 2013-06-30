$(function(){

    // Turn submit inputs into buttons
    $('input:submit').addClass('btn btn-primary');
    $('.nav_button').addClass('btn btn-primary');
    $('.classlist').addClass('table table-condensed classlist-table');
    
    // Make grey_buttons disabled buttons
    $('.gray_button').addClass('btn disabled').removeClass('gray_button');

    // replace pencil gifs by something prettier
    $('td a:has(img[src$="edit.gif"])').each(function () { $(this).html($(this).html().replace(/<img.*>/," <i class='icon-pencil'></i>")); });


    // Sets login form input to bigger size
    $('#login_form input').addClass('input-large');
    
    // Changes links in masthead
    $('#loginstatus a').addClass('btn btn-small');
    $('#loginstatus a').append(' <i class="icon-signout"></i>');
    
    // Changes edit links in info panels to buttons
    $("#info-panel-right a:contains('[edit]')").addClass('btn btn-small btn-info');
    $("#info-panel-right a:contains('[edit]')").text('Edit');

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
    $('.problem_set_table td a').addClass('btn btn-primary btn-small');
    $('#hardcopy-form').addClass('form-inline');

    $('.problem_set_options input').addClass('btn btn-info');
    $('.problem_set_options a').addClass('btn btn-info');

    // Problem formatting
    $('#problemMainForm').addClass('problem-main-form form-inline');
    $('.attemptResults').addClass('table table-condensed table-bordered');

    // Past answers formatting
    $('#past-answer-table').addClass('table');

    // Grades formatting
    $('#grades_table').addClass('table table-bordered table-condensed');
    $('#grades_table a').addClass('btn btn-primary');

    //Problem Grader formatting
    $('#problem-grader-form').addClass('form-inline');
    $('#problem-grader-form input:button').addClass('btn btn-small btn-info');

    //Instructor Tools formatting
    $('.ButtonRow .btn').addClass('btn-mini');
    $('.ButtonRowCenter .btn').addClass('btn-mini');
    $('.ScrollingRecordList .btn').addClass('btn-small');

    //CourseConfiguration
    $('#config-form').addClass('form-inline');
    $('#config-form table').addClass('table table-bordered');

    //File Manager Configuration
    $('#FileManager').addClass('form-inline');
    $('#FileManager .btn').addClass('btn-small file-manager-btn');

    //Classlist Editor 1&2 configuration
    $('#classlist-form').addClass('form-inline user-list-form');
    $('.user-list-form select').addClass('input-medium');
    $('.user-list-form input:button').addClass('btn btn-info');
    $('.user-list-form input:reset').addClass('btn btn-info');
    $('.user-list-form').wrapInner('<div />');
    $('.classlist-table').addClass('small-table-text table table-condensed');
    $('#show_hide').addClass('btn btn-info');

    //Homework sets editor config
    $('#problemsetlist').addClass('form-inline set-list-form');
    $('#problemsetlist2').addClass('form-inline set-list-form');
    $('.set-list-form select').addClass('input-medium');
    $('.set-list-form input:text').addClass('input-medium');
    $('.set-list-form select[name="action.filter.scope"]').addClass('input-large').removeClass('input-medium');
    $('.set-list-form select[name="action.import.source"]').addClass('input-large').removeClass('input-medium');
    $('.set-list-form input:button').addClass('btn btn-info');
    $('.set-list-form input:reset').addClass('btn btn-info');
    $('.set-list-form').wrapInner('<div />');
    $('.set_table').addClass('small-table-text table table-condensed');
    $('.set_table input:text').removeClass('input-medium');
    $('#show_hide').addClass('btn btn-info');
    $('#problem_set_form').addClass('form-inline');
    $('#user-set-form').addClass('form-inline user-assign-form');
    $('#set-user-form').addClass('form-inline user-assign-form');

    //PG editor styling
    $('#editor').addClass('form-inline span9');
    $('#editor a').addClass('btn btn-small btn-info');
    $('#editor div').each(function () { $(this).html($(this).html().replace(/\|/g,"")); });

    //Achievement Editor
    $('#achievement-list').addClass('form-inline user-list-form');
    $('.user-list-form select').addClass('input-medium');
    $('.user-list-form input:button').addClass('btn btn-info');
    $('.user-list-form input:reset').addClass('btn btn-info');
    $('.user-list-form').wrapInner('<div />');
    $('#show_hide').addClass('btn btn-info');
    $('#user-achievement-form').addClass('form-inline user-assign-form');

    //email page
    $('#send-mail-form').addClass('form-inline');
    $('#send-mail-form .btn').addClass('btn-small');

    //Score sets
    $('#scoring-form').addClass('form-inline');
    $('#scoring-form input:submit').addClass('btn-small');

    //Student progress and statistics
    $('table.progress-table').addClass('table table-bordered table-condensed');
    $('table.stats-table').addClass('table table-bordered');
    $('.stats-table td a').addClass('btn btn-small btn-primary');

    //Library browser 1 tweaks
    $('#mainform ').addClass('form-inline');
    $('#mainform input:button').addClass('btn btn-primary');
    $('#mainform .btn').addClass('btn-small');
    $('#mainform .InfoPanel select').addClass('input-xxlarge');
    $('#mainform select[name=mydisplayMode]').addClass('input-small').removeClass('input-xxlarge');
    $('#mainform select[name=local_sets]').addClass('input-small').removeClass('input-xxlarge');
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

})