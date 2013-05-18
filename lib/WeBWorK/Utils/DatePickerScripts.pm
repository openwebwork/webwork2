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

sub date_scripts {
	my $bareName = shift;
	my $timezone = shift;
	my $out = <<EOF;
addOnLoadEvent(function() {
var name = "$bareName";
var open_rule = \$('#' + name + '\\\\.open_date_id');
var due_rule = \$('#' + name + '\\\\.due_date_id');
var answer_rule = \$('#' + name + '\\\\.answer_date_id');
var dueDateOffset = 7; // 7 days after open date
var answerDateOffset = 5 //5 hours after due date

var update = function() {
	var openDate = open_rule.datetimepicker('getDate');
	var dueDate = due_rule.datetimepicker('getDate');
	var answerDate = answer_rule.datetimepicker('getDate');
// 	open_rule.removeClass("auto-changed");
//	due_rule.removeClass("auto-changed");
//	answer_rule.removeClass("auto-changed");
	if ( due_rule.val() =='') {
		dueDate = new Date(openDate);
        dueDate.setDate(dueDate.getDate()+dueDateOffset);
        due_rule.datetimepicker('setDate',dueDate);
        due_rule.addClass("auto-changed");
	} else if (openDate > due_rule.datetimepicker('getDate')) {
	    dueDate = new Date(openDate);
	    due_rule.datetimepicker('setDate',dueDate);
	    due_rule.addClass("auto-changed");
	}

	if ( answer_rule.val() =='') {
		answerDate = new Date(dueDate);
        answerDate.setHours(answerDate.getHours()+answerDateOffset);
        answer_rule.datetimepicker('setDate',answerDate);
        answer_rule.addClass("auto-changed");
	} else if (dueDate > answer_rule.datetimepicker('getDate')) {
	    answerDate = new Date(dueDate);
	    answer_rule.datetimepicker('setDate',answerDate);
	    answer_rule.addClass("auto-changed");

	}
}
open_rule.datetimepicker({
	ampm: true,
	timeFormat: 'hh:mmtt',
	timeSuffix: ' EDT',
	separator: ' at ',
    onClose: function(dateText, inst) {
        update();
    },
    onSelect: function (selectedDateTime){
        var open = \$(this).datetimepicker('getDate');
		var open_obj = new Date(open.getTime());
		open_rule.addClass("auto-changed");
        due_rule.datetimepicker('option', 'minDate', open_obj);
        due_rule.addClass("auto-changed");
        answer_rule.datetimepicker('option', 'minDate', open_obj);
        answer_rule.addClass("auto-changed");
    }
 });
due_rule.datetimepicker({
	ampm: true,
	timeFormat: 'hh:mmtt',
	timeSuffix: ' EDT',
	separator: ' at ',
    onClose: function(dateText, inst) {
        var open_changed=0;
    	if (open_rule.val() == "") {
    		var openDate = new Date(dateText);
    		openDate.setDate(openDate.getDate() -dueDateOffset );
    		open_rule.datetimepicker('setDate',openDate);
    		open_rule.addClass("auto-changed");	
    	}
    	update();
	},
    onSelect: function (selectedDateTime){
        var due = \$(this).datetimepicker('getDate');
		answer_rule.datetimepicker('option', 'minDate', new Date(due.getTime()));
		answer_rule.addClass("auto-changed");
    }
});

answer_rule.datetimepicker({
	ampm: true,
	timeFormat: 'hh:mmtt',
	timeSuffix: ' EDT',
	separator: ' at ',
    onClose: function(dateText, inst) {
        var open_changed=0;    
         if (open_rule.val() == "") {
    		var openDate = new Date(dateText);
    		openDate.setDate(openDate.getDate() - dueDateOffset );
    		openDate.setHours(openDate.getHours() - answerDateOffset);
    		open_rule.datetimepicker('setDate',openDate);
    		open_changed=1;
    	}
    	update();
    	if (open_changed) {open_rule.addClass("auto-changed");}
    },
    onSelect: function (selectedDateTime){
    }
});

});	
EOF
	$out;
}

# sub open_date_script {
# 	my $bareName = shift;  #get homework set name
# 	my $timezone = shift;
# 
# my $out = <<EOF;
# 
# \$('#$bareName\\\\.open_date_id').datetimepicker({
# 	ampm: true,
# 	timeFormat: 'hh:mmtt',
# 	timeSuffix: ' $timezone',
# 	separator: ' at ',
#     onClose: function(dateText, inst) {
#         var dueDateTextBox = \$('#$bareName\\\\.due_date_id');
#         if (dueDateTextBox.val() != '') {
#             var testopenDate = new Date(dateText);
#             var testdueDate = new Date(dueDateTextBox.val());
#             if (testopenDate > testdueDate)
#                 dueDateTextBox.val(dateText);
#         }
#         else {
#             dueDateTextBox.val(dateText);
#         }
#     },
#     onSelect: function (selectedDateTime){
#         var open = \$(this).datetimepicker('getDate');
# 		var open_obj = new Date(open.getTime());
#         \$('#$bareName\\\\.due_date_id').datetimepicker('option', 'minDate', open_obj);
#     }
#  });
# EOF
# 	$out;
# }
# 
# 
# sub due_date_script {
# 	my $bareName = shift;  #get homework set name
# 	my $timezone = shift;
# 
# my $out = <<EOF;
# \$('#$bareName\\\\.due_date_id').datetimepicker({
# 	ampm: true,
# 	timeFormat: 'hh:mmtt',
# 	timeSuffix: ' $timezone',
# 	separator: ' at ',
#     onClose: function(dateText, inst) {
# 		var openDateTextBox = \$('#$bareName\\\\.open_date_id');
#         var answersDateTextBox = \$('#$bareName\\\\.answer_date_id');
# 
#         if (openDateTextBox.val() != '') {
#             var testopenDate = new Date(openDateTextBox.val());
# 			var testdueDate = new Date(dateText);
#             if (testopenDate > testdueDate)
#                 openDateTextBox.val(dateText);
#         }
#         else {
#             openDateTextBox.val(dateText);
#         }
# 
# 		if (answersDateTextBox.val() != '') {
# 			var testdueDate = new Date(dateText);
# 			var testanswersDate = new Date(answersDateTextBox.val());
# 			if(testdueDate > testanswersDate)
# 				answersDateTextBox.val(dateText);
# 		}
# 		else {
# 			answersDateTextBox.val(dateText);
# 		}
#     },
#     onSelect: function (selectedDateTime){
#         var due = \$(this).datetimepicker('getDate');
#         \$('#$bareName\\\\.open_date_id').datetimepicker('option', 'maxDate', new Date(due.getTime()));
# 		\$('#$bareName\\\\.answer_date_id').datetimepicker('option', 'minDate', new Date(due.getTime()));
#     }
# });
# 
# EOF
# 	$out;
# }
# 
# sub answer_date_script {
# 	my $bareName = shift;  #get homework set name
# 	my $timezone = shift;
# 
# my $out = <<EOF;
# \$('#$bareName\\\\.answer_date_id').datetimepicker({
# 	ampm: true,
# 	timeFormat: 'hh:mmtt',
# 	timeSuffix: ' $timezone',
# 	separator: ' at ',
#     onClose: function(dateText, inst) {
#         var dueDateTextBox = \$('#$bareName\\\\.due_date_id');
#         if (dueDateTextBox.val() != '') {
#             var testdueDate = new Date(dueDateTextBox.val());
#             var testanswersDate = new Date(dateText);
#             if (testdueDate > testanswersDate)
#                 dueDateTextBox.val(dateText);
#         }
#         else {
#             dueDateTextBox.val(dateText);
#         }
#     },
#     onSelect: function (selectedDateTime){
#         var answers = \$(this).datetimepicker('getDate');
#         \$('#$bareName\\\\.due_date_id').datetimepicker('option', 'maxDate', new Date(answers.getTime()));
#     }
# });
# 
# EOF
# 	$out;
# }

1;