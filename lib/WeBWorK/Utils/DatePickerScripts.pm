################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseManagement.pm,v 1.48 2009/10/01 21:28:46 gage Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::Utils::DatePickerScripts;
use base qw(Exporter);
use WeBWorK::Utils qw(formatDateTime);
use POSIX;

sub date_scripts {
        my $ce = shift;
	my $set = shift;
	my $display_tz ||= $ce->{siteDefaults}{timezone};
	my $bareName = 'set.'.$set->set_id;
        $bareName =~ s/(\.|,)/\\\\$1/g;

	my $date = formatDateTime($set->open_date, $display_tz);
	$date =~ /\ ([A-Z]+)$/;	
	my $open_timezone = $1;

	$date = formatDateTime($set->due_date, $display_tz);
	$date =~ /\ ([A-Z]+)$/;	
	my $due_timezone = $1;

	$date = formatDateTime($set->answer_date, $display_tz);
	$date =~ /\ ([A-Z]+)$/;	
	my $answer_timezone = $1;        	

	my $reduced_credit_date_script_header = '';
	my $reduced_credit_date_script = '';
	my $reduced_credit_date_scoring_script = '';

	if ($ce->{pg}{ansEvalDefaults}{enableReducedScoring}) {
	    my $reduced_scoring_date;
	    my $default_reduced_scoring_period = 60*$ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};
	    
	    if ($set->reduced_scoring_date) {
		$reduced_scoring_date = $set->reduced_scoring_date;
	    } else {
		$reduced_scoring_date = $set->due_date - $default_reduced_scoring_period;
	    }
	    
	    $date = formatDateTime($reduced_scoring_date, $display_tz);
	    $date =~ /\ ([A-Z]+)$/;	
	    my $reduced_timezone = $1;        	
	    
	    $reduced_credit_date_script_header = "var reduced_rule = \$('#' + name + '\\\\.reduced_scoring_date_id');";

	    $reduced_credit_date_script = <<EOS;
	    reduced_rule.datetimepicker({
              showOn: "button",
	      buttonText: "<i class='icon-calendar'></i>",
	      ampm: true,
	      timeFormat: 'hh:mmtt',
	      timeSuffix: ' $reduced_timezone',
	      separator: ' at ',
	      constrainInput: false, 
	      onClose: function(dateText, inst) {
		  update();
		  reduced_rule.addClass('changed');
	      },
            });
EOS
       $reduced_credit_date_update_script = <<EOS;
	    var reducedDate = reduced_rule.datetimepicker('getDate');
	    if (openDate > reducedDate) {
		reducedDate = new Date(openDate);
		reduced_rule.datetimepicker('setDate',reducedDate);
		reduced_rule.addClass('changed');
	    }
	    if (dueDate < reducedDate) {
		reducedDate = new Date(dueDate);
		reduced_rule.datetimepicker('setDate',reducedDate);
		reduced_rule.addClass('changed');
	    }
EOS

	}

	my $out = <<EOF;
addOnLoadEvent(function() {
var name = "$bareName";
var open_rule = \$('#' + name + '\\\\.open_date_id');
var due_rule = \$('#' + name + '\\\\.due_date_id');
var answer_rule = \$('#' + name + '\\\\.answer_date_id');
var dueDateOffset = 7; // 7 days after open date
var answerDateOffset = 5; //5 hours after due date
$reduced_credit_date_script_header

var update = function() {
	var openDate = open_rule.datetimepicker('getDate');
	var dueDate = due_rule.datetimepicker('getDate');
	var answerDate = answer_rule.datetimepicker('getDate');
	if ( due_rule.val() =='') {
	    dueDate = new Date(openDate);
	    dueDate.setDate(dueDate.getDate()+dueDateOffset);
	    due_rule.datetimepicker('setDate',dueDate);
	    due_rule.addClass('changed');
	} else if (openDate > due_rule.datetimepicker('getDate')) {
	    dueDate = new Date(openDate);
	    due_rule.datetimepicker('setDate',dueDate);
	    due_rule.addClass('changed');
	}

	$reduced_credit_date_update_script

	if ( answer_rule.val() =='') {
		answerDate = new Date(dueDate);
		answerDate.setHours(answerDate.getHours()+answerDateOffset);
		answer_rule.datetimepicker('setDate',answerDate);
		answer_rule.addClass("changed");
	} else if (dueDate > answer_rule.datetimepicker('getDate')) {
	    answerDate = new Date(dueDate);
	    answer_rule.datetimepicker('setDate',answerDate);
	    answer_rule.addClass('changed');
	}

}
open_rule.datetimepicker({
              showOn: "button",
      buttonText: "<i class='icon-calendar'></i>",
	ampm: true,
	timeFormat: 'hh:mmtt',
	timeSuffix: ' $open_timezone',
	separator: ' at ',
	constrainInput: false, 
    onClose: function(dateText, inst) {
	open_rule.addClass('changed');
        update();
    },

/* the minDate option of datetimepicker is clobbering the time in the target
   object for some reason.  Commenting this out means that the dates dont
   change quite as dynamically, but they are still updated by the update() call

    onSelect: function (selectedDateTime){
        var open = \$(this).datetimepicker('getDate');
	var open_obj = new Date(open.getTime());
	open_rule.addClass("auto-changed");
        due_rule.datetimepicker('option', 'minDate', open_obj);
        answer_rule.datetimepicker('option', 'minDate', open_obj);
    }*/
 });
due_rule.datetimepicker({
              showOn: "button",
      buttonText: "<i class='icon-calendar'></i>",
	ampm: true,
	timeFormat: 'hh:mmtt',
	timeSuffix: ' $due_timezone',
	separator: ' at ',
	constrainInput: false, 
    onClose: function(dateText, inst) {
        var open_changed=0;
    	if (open_rule.val() == "") {
    		var openDate = new Date(dateText);
    		openDate.setDate(openDate.getDate() -dueDateOffset );
    		open_rule.datetimepicker('setDate',openDate);
    	}
	due_rule.addClass('changed');
    	update();
	},
/*    onSelect: function (selectedDateTime){
        var due = \$(this).datetimepicker('getDate');
	answer_rule.datetimepicker('option', 'minDateTime', new Date(due.getTime()));
	} */
});

answer_rule.datetimepicker({
              showOn: "button",
      buttonText: "<i class='icon-calendar'></i>",
	ampm: true,
	timeFormat: 'hh:mmtt',
	timeSuffix: ' $answer_timezone',
	separator: ' at ',
	constrainInput: false, 
    onClose: function(dateText, inst) {
        var open_changed=0;    
         if (open_rule.val() == "") {
    		var openDate = new Date(dateText);
    		openDate.setDate(openDate.getDate() - dueDateOffset );
    		openDate.setHours(openDate.getHours() - answerDateOffset);
    		open_rule.datetimepicker('setDate',openDate);
    	}
	answer_rule.addClass('changed');
    	update();
    },
    onSelect: function (selectedDateTime){
    }
});

$reduced_credit_date_script

});	
EOF

	return $out;
}



1;
