################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Constants.pm,v 1.62 2010/02/01 01:57:56 apizer Exp $
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

package WeBWorK::Constants;

=head1 NAME

WeBWorK::Constants - provide constant values for other WeBWorK modules.

=cut

use strict;
use warnings;

################################################################################
# WeBWorK::Debug
################################################################################

# If true, WeBWorK::Debug will print debugging output.
#
$WeBWorK::Debug::Enabled = 0;

# If non-empty, debugging output will be sent to the file named rather than STDERR.
#
$WeBWorK::Debug::Logfile = "";

# If defined, prevent subroutines matching the following regular expression from
# logging.
#
# For example, this pattern prevents the dispatch() function from logging:
#     $WeBWorK::Debug::DenySubroutineOutput = qr/^WeBWorK::dispatch$/;
#
$WeBWorK::Debug::DenySubroutineOutput = undef;

# If defined, allow only subroutines matching the following regular expression
# to log.
#
# For example, this pattern allow only some function being worked on to log:
#     $WeBWorK::Debug::AllowSubroutineOutput = qr/^WeBWorK::SomePkg::myFunc$/;
#
$WeBWorK::Debug::AllowSubroutineOutput = undef;

################################################################################
# WeBWorK::ContentGenerator::Hardcopy
################################################################################

# If true, don't delete temporary files
#
$WeBWorK::ContentGenerator::Hardcopy::PreserveTempFiles = 0;

################################################################################
# WeBWorK::PG::Local
################################################################################
# The maximum amount of time (in seconds) to work on a single problem.
# At the end of this time a timeout message is sent to the browser.

$WeBWorK::PG::Local::TIMEOUT = 60;

################################################################################
# WeBWorK::PG::ImageGenerator
################################################################################

# Arguments to pass to dvipng. This is dependant on the version of dvipng.
#
# For dvipng versions 0.x
#     $WeBWorK::PG::ImageGenerator::DvipngArgs = "-x4000.5 -bgTransparent -Q6 -mode toshiba -D180";
# For dvipng versions 1.0 to 1.5
#     $WeBWorK::PG::ImageGenerator::DvipngArgs = "-bgTransparent -D120 -q -depth";
#
# For dvipng versions 1.6 (and probably above)
#     $WeBWorK::PG::ImageGenerator::DvipngArgs = "-bgtransparent -D120 -q -depth";
# Note: In 1.6 and later, bgTransparent gives alpha-channel transparency while
# bgtransparent gives single-bit transparency. If you use alpha-channel transparency,
# the images will not be viewable with MSIE.  bgtransparent works for version 1.5,
# but does not give transparent backgrounds. It does not work for version 1.2. It has not
# been tested with other versions.
#
$WeBWorK::PG::ImageGenerator::DvipngArgs = "-bgTransparent -D120 -q -depth";

# If true, don't delete temporary files
#
$WeBWorK::PG::ImageGenerator::PreserveTempFiles = 0;

# TeX to prepend to equations to be processed.
#
$WeBWorK::PG::ImageGenerator::TexPreamble = <<'EOF';
\documentclass[12pt]{article}
\nonstopmode
\usepackage{amsmath,amsfonts,amssymb}
\def\gt{>}
\def\lt{<}
\usepackage[active,textmath,displaymath]{preview}
\begin{document}
EOF

# TeX to append to equations to be processed.
#
$WeBWorK::PG::ImageGenerator::TexPostamble = <<'EOF';
\end{document}
EOF

################################################################################
# WeBWorK::ContentGenerator::Instructor::Config
################################################################################

# Configuation data
# It is organized by section.  The allowable types are
#  'text' for a text string (no quote marks allowed),
#  'number' for a number,
#  'list' for a list of text strings,
#  'permission' for a permission value,
#  'boolean' for variables which really hold 0/1 values as flags.
#  'checkboxlist' for variables which really hold a list of values which
#      can be independently picked yes/no as checkboxes

$WeBWorK::ContentGenerator::Instructor::Config::ConfigValues = [
    ['General',
		{ var => 'courseFiles{course_info}',
		  doc => 'Name of course information file',
		  doc2 => 'The name of course information file (located in the templates directory). Its contents are displayed in the right panel next to the list of homework sets.',
		  type => 'text'},
		{ var => 'defaultTheme',
		  doc => 'Theme (refresh page after saving changes to reveal new theme)',
		  doc2 => 'There are currently five themes (or skins) to choose from: ur, math, math2, and dgage.  The theme
specifies a unified look and feel for the WeBWorK course web pages.',
		  values => [qw(math math2 math3 ur dgage  union)],
		  type => 'popuplist'},
		{ var => 'sessionKeyTimeout',
		  doc => 'Inactivity time before a user is required to login again',
		  doc2 => 'Length of time, in seconds, a user has to be inactive before he is required to login again.<p> This value should be entered as a number, so as 3600 instead of 60*60 for one hour',
		  type => 'number'},
		{ var => 'siteDefaults{timezone}',
		  doc => 'Timezone for the course',
		  doc2 => 'Some servers handle courses taking place in different timezones.  If this course is not showing the correct timezone, enter the correct value here.  The format consists of unix times, such as "America/New_York","America/Chicago", "America/Denver", "America/Phoenix" or "America/Los_Angeles". Complete list: <a href="http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones">TimeZoneFiles</a>',
		  type => 'text'},],
	['Permissions',
		{ var => 'permissionLevels{login}',
		  doc => 'Allowed to login to the course',
		  type => 'permission'},
		{ var => 'permissionLevels{change_password}',
		  doc => 'Allowed to change their password',
		  doc2 => 'Users at this level and higher are allowed to change their password. Normally guest users are not allowed to change their password.',
		  type => 'permission'},
		{ var => 'permissionLevels{become_student}',
		  doc => 'Allowed to <em>act as</em> another user',
		  type => 'permission'},
		{ var => 'permissionLevels{submit_feedback}',
		  doc => 'Can e-mail instructor',
		  doc2 => 'Only this permission level and higher get buttons for sending e-mail to the instructor.',
		  type => 'permission'},
		{ var => 'permissionLevels{record_answers_when_acting_as_student}',
		  doc => 'Can submit answers for a student',
		  doc2 => 'When acting as a student, this permission level and higher can submit answers for that student.',
		  type => 'permission'},
		{ var => 'permissionLevels{report_bugs}',
		  doc => 'Can report bugs',
		  doc2 => 'Users with at least this permission level get a link in the left panel for reporting bugs to the bug tracking system in Rochester',
		  type => 'permission'},
		{ var => 'permissionLevels{change_email_address}',
		  doc => 'Allowed to change their e-mail address',
		  doc2 => 'Users at this level and higher are allowed to change their e-mail address. Normally guest users are not allowed to change the e-mail address since it does not make sense to send e-mail to anonymous accounts.',
		  type => 'permission'},
		{ var => 'permissionLevels{view_answers}',
		  doc => 'Allowed to view past answers',
		  doc2 => 'These users and higher get the "Show Past Answers" button on the problem page.',
		  type => 'permission'},
		{ var => 'permissionLevels{view_unopened_sets}',
		  doc => 'Allowed to view problems in sets which are not open yet',
		  type => 'permission'},
		{ var => 'permissionLevels{show_correct_answers_before_answer_date}',
		  doc => 'Allowed to see the correct answers before the answer date',
		  type => 'permission'},
		{ var => 'permissionLevels{show_solutions_before_answer_date}',
		  doc => 'Allowed to see solutions before the answer date',
		  type => 'permission'},
		{ var => 'permissionLevels{can_show_old_answers_by_default}',
		  doc => 'Can show old answers by default',
		  doc2 => 'When viewing a problem, WeBWorK usually puts the previously submitted answer in the answer blank if it is before the due date.  Below this level, old answers are never initially shown.  Typically, that is the desired behaviour for guest accounts.',
		  type => 'permission'},
		{ var => 'permissionLevels{can_always_use_show_old_answers_default}',
		  doc => 'Can always show old answers by default',
		  doc2 => 'When viewing a problem, WeBWorK usually puts the previously submitted answer in the answer blank if it is before the due date.  At this level and higher, old answers are always shown (independent of the answer date).',
		  type => 'permission'},
	],
	['PG - Problem Display/Answer Checking',
		{ var => 'pg{displayModes}',
		  doc => 'List of display modes made available to students',
		  doc2 => 'When viewing a problem, users may choose different methods of rendering
 formulas via an options box in the left panel.  Here, you can adjust what display modes are
 listed.<p>
 Some display modes require other software to be installed on the server.  Be sure to check
 that all display modes selected here work from your server.<p>
 The display modes are <ul>
<li> plainText: shows the raw LaTeX strings for formulas.
<li> formattedText: formulas are passed through the external program <code>tth</code>,
 which produces an HTML version of them.  Some browsers do not display all of the fonts
 properly.
<li> images: produces images using the external programs LaTeX and dvipng.
<li> jsMath: uses javascript to place symbols, which may come from fonts or images
 (the choice is configurable by the end user).
<li> MathJax: a successor to jsMath, uses javascript to place render mathematics.
<li> asciimath: renders formulas client side using ASCIIMathML
<li> LaTeXMathML: renders formulas client side using LaTeXMathML
</ul>
<p>
You must use at least one display mode.  If you select only one, then the options box will
 not give a choice of modes (since there will only be one active).',
		  min  => 1,
		  values => ["MathJax", "images", "plainText", "formattedText",  "jsMath",  "asciimath", "LaTeXMathML"],
		  type => 'checkboxlist'},

		{ var => 'pg{options}{displayMode} ',
		  doc => 'The default display mode',
		  doc2 => 'Enter one of the allowed display mode types above.  See \'display modes entry\' for descriptions.',
		  min  => 1,
		  type => 'text'},
		  
		{ var => 'pg{options}{showEvaluatedAnswers}',
		  doc => 'Display the evaluated student answer',
		  doc2 => 'Set to true to display the "Entered" column which automatically shows the evaluated student answer, e.g. 1 
		  if student input is sin(pi/2). If this is set to false, e.g. to save space in the response area, the student can 
		  still see their evaluated answer by hovering the mouse pointer over the typeset version of their answer.',
		  type => 'boolean'},		  

		{ var => 'pg{ansEvalDefaults}{useBaseTenLog}',
		  doc => 'Use log base 10 instead of base <i>e</i>',
		  doc2 => 'Set to true for log to mean base 10 log and false for log to mean natural logarithm',
		  type => 'boolean'},

		{ var => 'pg{ansEvalDefaults}{useOldAnswerMacros}',
		  doc => 'Use older answer checkers',
		  doc2 => 'During summer 2005, a newer version of the answer checkers was implemented for answers which are functions and numbers.  The newer checkers allow more functions in student answers, and behave better in certain cases.  Some problems are specifically coded to use new (or old) answer checkers.  However, for the bulk of the problems, you can choose what the default will be here.  <p>Choosing <i>false</i> here means that the newer answer checkers will be used by default, and choosing <i>true</i> means that the old answer checkers will be used by default.',
		  type => 'boolean'},

		{ var => 'pg{ansEvalDefaults}{defaultDisplayMatrixStyle}',
		  doc => 'Control string for displaying matricies',
		  doc2 => 'String of three characters for defining the defaults for displaying matricies.  The first and last characters give the left and right delimiters of the matrix, so usually one of ([| for a left delimiter, and one of )]| for the right delimiter.  It is also legal to specify "." for no delimiter. <p> The middle character indicates how to display vertical lines in a matrix (e.g., for an augmented matrix).  This can be s for solid lines and d for dashed lines.  While you can specify the defaults, individual problems may override these values.',
		  type => 'text'},

		{ var => 'pg{ansEvalDefaults}{numRelPercentTolDefault}',
		  doc => 'Allowed error, as a percentage, for numerical comparisons',
		  doc2 => "When numerical answers are checked, most test if the student's answer
 is close enough to the programmed answer be computing the error as a percentage of
 the correct answer.  This value controls the default for how close the student answer
 has to be in order to be marked correct.
<p>
A value such as 0.1 means 0.1 percent error is allowed.",
		  type => 'number'},
		{ var => 'pg{ansEvalDefaults}{reducedScoringPeriod}',
		  doc => 'Length of Reduced Credit Period in minutes',
		  doc2 => 'The Reduced Credit Period (formally called the Reduced Scoring Period) is a period before the due date during which
 all additional work done by the student counts at a reduced rate. Here is where 
 you set the length of this period in minutes. If this value is greater than 0, a
 message like "This assignment has a Reduced Credit Period that begins 11/08/2009 
 at 06:17pm EST and ends on the due date, 11/10/2009 at 06:17pm EST. During this 
 period all additional work done counts 50% of the original." will be displayed.<p>
 To use this, you also have to enable Reduced Credit for individual assignments by
 editing the set data using the Hmwk Sets Editor.<p>
 This works with the avg_problem_grader (which is the the default grader) and the 
 std_problem_grader (the all or nothing grader).  It will work with custom graders
 if they are written appropriately.' ,
		  type => 'number'},
		{ var => 'pg{ansEvalDefaults}{reducedScoringValue}',
		  doc => 'Value of work done in Reduced Credit Period' ,
		  doc2 => 'The Reduced Credit Period (formally called the Reduced Scoring Period) is a period before the due date during which
 all additional work done by the student counts at a reduced rate. Here is where 
 you set the reduced rate which must be a number in the interval [0,1]. 1 means no 
 reduction. For example if this value is .5 and a student views a problem during the
 Reduced Credit Period, they will see the message "You are in the Reduced Credit 
 Period: All additional work done counts 50% of the original." <p>
 To use this, you also have to enable Reduced Credit for individual assignments by
 editing the set data using the Hmwk Sets Editor.<p>
 This works with the avg_problem_grader (which is the the default grader) and the 
 std_problem_grader (the all or nothing grader).  It will work with custom graders
 if they are written appropriately.' ,
		  type => 'number'},
	],
	['E-Mail',
		{ var => 'mail{feedbackSubjectFormat}',
		  doc => 'Format for the subject line in feedback e-mails',
		  doc2 => 'When students click the <em>Email Instructor</em> button
 to send feedback, WeBWorK fills in the subject line.  Here you can set the
 subject line.  In it, you can have various bits of information filled in
 with the following escape sequences.
<p>
<ul>
<li> %c = course ID
<li> %u = user ID
<li> %s = set ID
<li> %p = problem ID
<li> %x = section
<li> %r = recitation
<li> %% = literal percent sign
</ul>',
		  width => 45,
		  type => 'text'},
		{ var => 'mail{feedbackVerbosity}',
		  doc => 'E-mail verbosity level',
		  doc2 => 'The e-mail verbosity level controls how much information is
 automatically added to feedback e-mails.  Levels are
<ol>
<li value="0"> send only the feedback comment and context link
<li value="1"> as in 0, plus user, set, problem, and PG data
<li value="2"> as in 1, plus the problem environment (debugging data)
</ol>',
		  type => 'number'
		},
		{ var => 'mail{allowedRecipients}',
		  doc => 'E-mail addresses which can receive e-mail from a pg problem',
		  doc2 => 'List of e-mail addresses to which e-mail can be sent by a problem. Professors need to be added to this list if questionaires are used, or other WeBWorK problems which send e-mail as part of their answer mechanism.',
		  type => 'list'},
		{ var => 'permissionLevels{receive_feedback}',
		  doc => 'E-mail feedback from students automatically sent to this permission level and higher:',
		  doc2 => 'Users with this permssion level or greater will automatically be sent feedback from students (generated when they use the "Contact instructor" button on any problem page).  In addition the feedback message will be sent to addresses listed below.  To send ONLY to addresses listed below set permission level to "nobody".',
		  type => 'permission'},

		{ var => 'mail{feedbackRecipients}',
		  doc => 'Additional addresses for receiving feedback e-mail.',
		  doc2 => 'By default, feeback is sent to all users above who have permission to receive feedback. Feedback is also sent to any addresses specified in this blank. Separate email address entries by commas.',
		  type => 'list'},
	]
];

1;
