################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Constants.pm,v 1.32 2005/10/02 19:51:44 jj Exp $
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
		{ var => 'sessionKeyTimeout',
		  doc => 'Inactivity time before a user is required to login again',
		  doc2 => 'Length of time, in seconds, a user has to be inactive before he is required to login again.<p> This value should be entered as a number, so as 3600 instead of 60*60 for one hour',
		  type => 'number'}],
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
		{ var => 'permissionLevels{record_answers_when_acting_as_student}',
		  doc => 'Can submit answers for a student',
		  doc2 => 'When acting as a student, this permission level and higher can submit answers for that student.',
		  type => 'permission'},
		{ var => 'permissionLevels{report_bugs}',
		  doc => 'Can report bugs',
		  doc2 => 'Users with at least this permission level get a link in the left panel for reporting bugs to the bug tracking system in Rochester',
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
<li> asciimath: renders formulas client side using ASCIIMathML
</ul>
<p>
You must use at least one display mode.  If you select only one, then the options box will
 not give a choice of modes (since there will only be one active).',
		  min  => 1,
		  values => ["plainText", "formattedText", "images", "jsMath", "asciimath"],
		  type => 'checkboxlist'},
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
		{ var => 'mail{allowedRecipients}',
		  doc => 'E-mail addresses which can recieve e-mail from a pg problem',
		  doc2 => 'List of e-mail addresses to which e-mail can be sent by a problem. Professors need to be added to this list if questionaires are used, or other WeBWorK problems which send e-mail as part of their answer mechanism.',
		  type => 'list'},
		{ var => 'mail{allowedFeedback}',
		  doc => 'Extra addresses for recieving feedback e-mail',
		  doc2 => 'By default, feeback is sent to all users who have permission to receive feedback. If this list is non-empty, feedback is also sent to the addresses specified here.',
		  type => 'list'},
	]
];

1;
