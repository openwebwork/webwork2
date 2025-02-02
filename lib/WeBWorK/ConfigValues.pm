################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ConfigValues;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::ConfigValues - Configuration values for a course.

=head1 DESCRIPTION

Configuration values. These are organized by section. The following types are
allowed.

=over

=item text

A text string (no quotes allowed).

=item number

A number.

=item list

A list of text strings.

=item permission

A permission value.

=item boolean

Variables which really hold 0/1 values as flags.

=item timezone

A time zone.

=item time

A time.

=item checkboxlist

Variables that hold a list of values which can be independently picked yes/no as
checkboxes.

=item popuplist

Variables that hold a list of values to be selected from.

=item setting

Values in the course setting database table.

=item lms_context_id

This is specifically for The LMS context id used for content selection.

=back

=cut

use Mojo::File qw(path);

use WeBWorK::Utils qw(x);

our @EXPORT_OK = qw(getConfigValues);

sub getConfigValues ($ce) {
	my $configValues = [
		[
			x('General'),
			{
				var  => 'courseTitle',
				doc  => x('Title for course displayed on the Assignments page'),
				type => 'setting'
			},
			{
				var  => 'courseFiles{course_info}',
				doc  => x('Name of course information file'),
				doc2 => x(
					'The name of course information file (located in the templates directory). '
						. 'Its contents are displayed in the right panel next to the list of homework sets.'
				),
				type => 'text'
			},
			{
				var  => 'defaultTheme',
				doc  => x('Theme'),
				doc2 => x(
					'There is one main theme to choose from: math4. It has three variants: math4-green, '
						. 'math4-red, and math4-yellow. The theme specifies a unified look and feel for the '
						. 'WeBWorK course web pages.'
				),
				values  => [qw(math4 math4-green math4-red)],
				type    => 'popuplist',
				hashVar => '{defaultTheme}'
			},
			{
				var  => 'language',
				doc  => x('Language'),
				doc2 =>
					x('WeBWorK currently has translations for the languages listed in the course configuration.'),
				values => [qw(en tr es fr zh-HK he)],
				type   => 'popuplist'
			},
			{
				var  => 'studentDateDisplayFormat',
				doc  => x('Format of dates that are displayed for students'),
				doc2 => x(
					'This is the format of the dates displayed for students. This can be created from '
						. '<a href="https://metacpan.org/pod/DateTime#strftime-Patterns">strftime patterns</a>, '
						. 'e.g., <span class="text-nowrap">"%a %b %d at %l:%M%P"</span>, or can be one of the '
						. '<a href="https://metacpan.org/pod/DateTime::Locale::FromData">localizable formats</a> '
						. '"datetime_format_short", "datetime_format_medium", "datetime_format_long", or '
						. '"datetime_format_full".'
				),
				type => 'text'
			},
			{
				var  => 'perProblemLangAndDirSettingMode',
				doc  => x('Mode in which the LANG and DIR settings for a single problem are determined.'),
				doc2 => x(
					'<p>Mode in which the LANG and DIR settings for a single problem are determined.</p><p>The '
						. 'system will set the LANGuage attribute to either a value determined from the problem, a '
						. 'course-wide default, or the system default, depending on the mode selected. The tag will '
						. 'only be added to the DIV enclosing the problem if it is different than the value which '
						. 'should be set in the main HTML tag set for the entire course based on the course language.'
						. '</p><p>There are two options for the DIRection attribute: "ltr" for left-to-write scripts, '
						. 'and "rtl" for right-to-left scripts like Arabic and Hebrew.</p><p>The DIRection attribute '
						. 'is needed to trigger proper display of the question text when the problem text-direction '
						. 'is different than that used by the current language of the course. For example, English '
						. 'problems from the library browser would display improperly in RTL mode for a Hebrew course, '
						. 'unless the problen Direction is set to LTR.</p><p>The feature to set a problem language and '
						. 'direction was only added in 2018 to the PG language, so most problems will not declare '
						. 'their language, and the system needs to fall back to determining the language and direction '
						. 'in a different manner. The OPL itself is all English, so the system wide fallback is to '
						. 'en-US in LTR mode.</p><p>Since the defaults fall back to the LTR direction, most sites '
						. 'should be fine with the "auto::" mode, but may want to select the one which matches their '
						. 'course language. The mode "force::ltr" would also be an option for a course which runs into '
						. 'trouble with the "auto" modes.</p><p>Modes:</p><ul><li>"none" prevents any additional LANG '
						. 'and/or DIR tag being added. The browser will use the main setting which was applied to the '
						. 'entire HTML page. This is likely to cause trouble when a problem of the other direction is '
						. 'displayed.</li><li>"auto::" allows the system to make the settings based on the language '
						. 'and direction reported by the problem (a new feature, so not set in almost all existing '
						. 'problems) and falling back to the expected default of en-US in LTR mode. </li>'
						. '<li>"auto:LangCode:Dir" allows the system to make the settings based on the language and '
						. 'direction reported by the problem (a new feature, so not set in almost all existing '
						. 'problems) but falling back to the language with the given LangCode and the direction Dir '
						. 'when problem settings are not available from PG.</li><li>"auto::Dir" for problems without '
						. 'PG settings, this will use the default en=english language, but force the direction to '
						. 'Dir. Problems with PG settings will get those settings.</li><li>"auto:LangCode:" for '
						. 'problems without PG settings, this will use the default LTR direction, but will set the '
						. 'language to LangCode.Problems with PG settings will get those settings.</li>'
						. '<li>"force:LangCode:Dir" will <b>ignore</b> any setting made by the PG code of the problem, '
						. 'and will force the system to set the language with the given LangCode and the direction to '
						. 'Dir for <b>all</b> problems.</li><li>"force::Dir" will <b>ignore</b> any setting made by '
						. 'the PG code of the problem, and will force the system to set the direction to Dir for '
						. '<b>all</b> problems, but will avoid setting any language attribute for individual '
						. 'problem.</li></ul>'
				),
				values => [
					qw(none auto:: force::ltr force::rtl force:en:ltr auto:en:ltr force:tr:ltr auto:tr:ltr force:es:ltr
						auto:es:ltr force:fr:ltr auto:fr:ltr force:zh_hk:ltr auto:zh_hk:ltr force:he:rtl auto:he:rtl)
				],
				type => 'popuplist'
			},
			{
				var  => 'sessionTimeout',
				doc  => x('Inactivity time before a user is required to login again'),
				doc2 => x(
					'Length of time, in seconds, a user has to be inactive before he is required to login again. '
						. 'This value should be entered as a number, so as 3600 instead of 60*60 for one hour.'
				),
				type => 'number'
			},
			{
				var  => 'siteDefaults{timezone}',
				doc  => x('Timezone for the course'),
				doc2 => x(
					'<p>Some servers handle courses taking place in different timezones. If this course is not '
						. 'showing the correct timezone, enter the correct value here. The format consists of unix '
						. 'times, such as "America/New_York", "America/Chicago", "America/Denver", "America/Phoenix" '
						. 'or "America/Los_Angeles".</p>Complete list: '
						. '<a href="http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones">TimeZoneFiles</a>'
				),
				type    => 'timezone',
				hashVar => '{siteDefaults}->{timezone}'
			},
			{
				var  => 'hardcopyThemes',
				doc  => x('Enabled Site Hardcopy Themes'),
				doc2 => x(
					'Choose which of the site PDF hardcopy themes are available. In addition to the themes selected '
						. 'here, all themes in the course hardcopyThemes folder will be available. Your selection '
						. 'must be saved and then the page must be reloaded before the new list of enabled themes '
						. 'will be reflected in the selections that follows.'
				),
				values  => [qw(empty.xml)],
				type    => 'checkboxlist',
				min     => 1,
				hashVar => '{hardcopyThemes}'
			},
			{
				var     => 'hardcopyTheme',
				doc     => x('Hardcopy Theme'),
				doc2    => x('Choose a layout/styling theme for PDF hardcopy production.'),
				values  => [qw(empty.xml)],
				type    => 'popuplist',
				hashVar => '{hardcopyTheme}'
			},
			{
				var     => 'hardcopyThemePGEditor',
				doc     => x('Hardcopy Theme for Problem Editor'),
				doc2    => x('Choose a layout/styling theme for PDF hardcopy production from the Prooblem Editor.'),
				values  => [qw(empty.xml)],
				type    => 'popuplist',
				hashVar => '{hardcopyThemePGEditor}'
			},
			{
				var  => 'showCourseHomeworkTotals',
				doc  => x('Show Total Homework Grade on Grades Page'),
				doc2 => x(
					'When this is on students will see a line on the Grades page which has their total cumulative '
						. 'homework score. This score includes all sets assigned to the student.'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{options}{enableProgressBar}',
				doc  => x('Enable Progress Bar and current problem highlighting'),
				doc2 => x(
					'A switch to govern the use of a Progress Bar for the student; this also enables/disables the '
						. 'highlighting of the current problem in the side bar, and whether it is correct (&#x2713;), '
						. 'in progress (&hellip;), incorrect (&#x2717;), or unattempted (no symbol).'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{timeAssignDue}',
				doc  => x('Default Time that the Assignment is Due'),
				doc2 => x(
					'The time of the day that the assignment is due. This can be changed on an individual basis, '
						. 'but WeBWorK will use this value for default when a set is created.'
				),
				type    => 'time',
				hashVar => '{pg}->{timeAssignDue}'
			},
			{
				var  => 'pg{assignOpenPriorToDue}',
				doc  => x('Default Amount of Time (in minutes) before Due Date that the Assignment is Open'),
				doc2 => x(
					'The amount of time (in minutes) before the due date when the assignment is opened. You can '
						. 'change this for individual homework, but WeBWorK will use this value when a set is created.'
				),
				type    => 'number',
				hashVar => '{pg}->{assignOpenPriorToDue}'
			},
			{
				var  => 'pg{answersOpenAfterDueDate}',
				doc  => x('Default Amount of Time (in minutes) after Due Date that Answers are Open'),
				doc2 => x(
					'The amount of time (in minutes) after the due date that the Answers are available to student to '
						. 'view. You can change this for individual homework, but WeBWorK will use this value when '
						. 'a set is created.'
				),
				type    => 'number',
				hashVar => '{pg}->{answersOpenAfterDueDate}'
			},
		],
		[
			x('Optional Modules'),
			{
				var  => 'achievementsEnabled',
				doc  => x('Enable Course Achievements'),
				doc2 => x(
					'Activiating this will enable Mathchievements for webwork. Mathchievements can be managed '
						. 'by using the Achievements Manager link.'
				),
				type => 'boolean'
			},
			{
				var  => 'achievementPointsPerProblem',
				doc  => x('Achievement Points Per Problem'),
				doc2 => x('This is the number of achievement points given to each user for completing a problem.'),
				type => 'number'
			},
			{
				var  => 'achievementPointsPerProblemReduced',
				doc  => x('Achievement Points Per Problem in Reduced Scoring Period'),
				doc2 => x(
					'This is the number of achievement points given to each user for completing a problem if the '
						. 'problem is in a set that is in the reduced scoring period.'
				),
				type => 'number'
			},
			{
				var  => 'achievementItemsEnabled',
				doc  => x('Enable Achievement Rewards'),
				doc2 => x(
					'Activating this will enable achievement rewards. This feature allows students to earn rewards by '
						. 'completing achievements that allow them to affect their homework in a limited way.'
				),
				type => 'boolean'
			},
			{
				var  => 'achievementExcludeSet',
				doc  => x('List of sets excluded from achievements'),
				doc2 => x(
					'Comma separated list of set names that are excluded from all achievements. '
						. 'No achievement points and badges can be earned for submitting problems in these sets. '
						. 'Note that underscores (_) must be used for spaces in set names.'
				),
				type => 'list'
			},
			{
				var  => 'mail{achievementEmailFrom}',
				doc  => x('Email address to use when sending Achievement notifications.'),
				doc2 => x(
					'This email address will be used as the sender for achievement notifications. '
						. 'Achievement notifications will not be sent unless this is set.'
				),
				width => 45,
				type  => 'text'
			},
			{
				var  => 'options{enableConditionalRelease}',
				doc  => x('Enable Conditional Release'),
				doc2 => x(
					'Enables the use of the conditional release system. To use conditional release you need to '
						. 'specify a list of set names on the Problem Set Detail Page, along with a minimum score. '
						. 'Students will not be able to access that homework set until they have achieved the '
						. 'minimum score on all of the listed sets.'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{ansEvalDefaults}{enableReducedScoring}',
				doc  => x('Enable Reduced Scoring'),
				doc2 => x(
					'<p>This sets whether the Reduced Scoring system will be enabled. If enabled you will need '
						. 'to set the default length of the reduced scoring period and the value of work done in '
						. 'the reduced scoring period below.</p><p>To use this, you also have to enable Reduced '
						. 'Scoring for individual assignments and set their Reduced Scoring Dates by editing the '
						. 'set data.</p><p>This works with the avg_problem_grader (which is the default grader) '
						. 'and the std_problem_grader (the all or nothing grader). It will work with custom graders '
						. 'if they are written appropriately.</p>'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{ansEvalDefaults}{reducedScoringValue}',
				doc  => x('Value of work done in Reduced Scoring Period'),
				doc2 => x(
					'<p>After the Reduced Scoring Date all additional work done by the student counts at a reduced '
						. 'rate. Here is where you set the reduced rate which must be a percentage. For example if '
						. 'this value is 50% and a student views a problem during the Reduced Scoring Period, they '
						. 'will see the message "You are in the Reduced Scoring Period: All additional work done '
						. 'counts 50% of the original." </p><p>To use this, you also have to enable Reduced Scoring '
						. 'and set the Reduced Scoring Date for individual assignments by editing the set data '
						. 'using the Sets Manager.</p><p>This works with the avg_problem_grader (which is the '
						. 'default grader) and the std_problem_grader (the all or nothing grader). It will work '
						. 'with custom graders if they are written appropriately.</p>'
				),
				labels => {
					'0.1'  => '10%',
					'0.15' => '15%',
					'0.2'  => '20%',
					'0.25' => '25%',
					'0.3'  => '30%',
					'0.35' => '35%',
					'0.4'  => '40%',
					'0.45' => '45%',
					'0.5'  => '50%',
					'0.55' => '55%',
					'0.6'  => '60%',
					'0.65' => '65%',
					'0.7'  => '70%',
					'0.75' => '75%',
					'0.8'  => '80%',
					'0.85' => '85%',
					'0.9'  => '90%',
					'0.95' => '95%',
					'1'    => '100%'
				},
				values => [qw(1 0.95 0.9 0.85 0.8 0.75 0.7 0.65 0.6 0.55 0.5 0.45 0.4 0.35 0.3 0.25 0.2 0.15 0.1)],
				type   => 'popuplist'
			},
			{
				var  => 'pg{ansEvalDefaults}{reducedScoringPeriod}',
				doc  => x('Default Length of Reduced Scoring Period in minutes'),
				doc2 => x(
					'The Reduced Scoring Period is the default period before the due date during which all '
						. 'additional work done by the student counts at a reduced rate. When enabling reduced '
						. 'scoring for a set the reduced scoring date will be set to the due date minus this '
						. 'number. The reduced scoring date can then be changed. If the Reduced Scoring is enabled '
						. 'and if it is after the reduced scoring date, but before the due date, a message like '
						. '"This assignment has a Reduced Scoring Period that begins 11/08/2009 at 06:17pm EST '
						. 'and ends on the due date, 11/10/2009 at 06:17pm EST. During this period all additional '
						. 'work done counts 50% of the original." will be displayed.'
				),
				type => 'number'
			},
			{
				var  => 'pg{options}{enableShowMeAnother}',
				doc  => x('Enable Show Me Another button'),
				doc2 => x(
					'Enables use of the Show Me Another button, which offers the student a newly-seeded version '
						. 'of the current problem, complete with solution (if it exists for that problem).'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{options}{showMeAnotherDefault}',
				doc  => x('Default number of attempts before Show Me Another can be used (-1 => Never)'),
				doc2 => x(
					'This is the default number of attempts before show me another becomes available to students. '
						. 'It can be set to -1 to disable show me another by default.'
				),
				type => 'number'
			},
			{
				var  => 'pg{options}{showMeAnotherMaxReps}',
				doc  => x('Maximum times Show me Another can be used per problem (-1 => unlimited)'),
				doc2 => x(
					'The Maximum number of times Show me Another can be used per problem by a student. '
						. 'If set to -1 then there is no limit to the number of times that Show Me Another can be used.'
				),
				type => 'number'
			},
			{
				var  => 'pg{options}{showMeAnother}',
				doc  => x('List of options for Show Me Another button'),
				doc2 => x(
					'<ul><li><b>SMAcheckAnswers</b>: Enables the "Check Answers" button <i>for the new problem</i> '
						. 'when the "Show Me Another" button is clicked.</li><li><b>SMAshowSolutions</b>: Shows the '
						. 'solution <i>for the new problem</i> when the "Show Me Another" button is clicked (assuming '
						. 'that a solution exists).</li><li><b>SMAshowCorrect</b>: Correct answers <i>for the new '
						. 'problem</i> can be viewed when the "Show Me Another" button is clicked. Note that '
						. 'SMACheckAnswers must also be enabled or the student will have no way to view correct '
						. 'answers.</li><li><b>SMAshowHints</b>: Show hints <i>for the new problem</i> (assuming '
						. 'hints exist).</li></ul>Note: There is very little point enabling the Show Me Another '
						. 'feature unless you check at least one of these options. Otherwise the students would '
						. 'simply see a new version that cannot be attempted or learned from.'
				),
				min    => 0,
				values => [ 'SMAcheckAnswers', 'SMAshowSolutions', 'SMAshowCorrect', 'SMAshowHints' ],
				type   => 'checkboxlist'
			},
			{
				var  => 'pg{options}{enablePeriodicRandomization}',
				doc  => x('Enable periodic re-randomization of problems'),
				doc2 => x(
					'Enables periodic re-randomization of problems after a given number of attempts. Student would '
						. 'have to click Request New Version to obtain new version of the problem and to continue '
						. 'working on the problem'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{options}{periodicRandomizationPeriod}',
				doc  => x('The default number of attempts between re-randomization of the problems ( 0 => never)'),
				doc2 => x('The default number of attempts before the problem is re-randomized. ( 0 => never )'),
				type => 'number'
			},
			{
				var  => 'pg{options}{showCorrectOnRandomize}',
				doc  => x('Show the correct answer to the current problem before re-randomization.'),
				doc2 => x(
					'Show the correct answer to the current problem on the last attempt before a new version is '
						. 'requested.'
				),
				type => 'boolean'
			},
		],
		[
			x('Permissions'),
			{
				var  => 'permissionLevels{login}',
				doc  => x('Allowed to login to the course'),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{change_password}',
				doc  => x('Allowed to change their password'),
				doc2 => x(
					'Users at this level and higher are allowed to change their password. '
						. 'Normally guest users are not allowed to change their password.'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{become_student}',
				doc  => x('Allowed to <em>act as</em> another user'),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{submit_feedback}',
				doc  => x('Can email instructor'),
				doc2 => x('Only this permission level and higher get buttons for sending email to the instructor.'),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{problem_grader}',
				doc  => x('Can use problem grader'),
				doc2 => x(
					'This permission level and higher can use the problem grader (both the grader that is available '
						. 'on a problem page and the set-wide probelem grader).'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{record_answers_when_acting_as_student}',
				doc  => x('Can submit answers for a student'),
				doc2 => x(
					'When acting as a student, this permission level and higher can submit answers for that student, '
						. 'which includes starting and grading test versions.  This permission should only be turned '
						. 'on temporarily and set back to "nobody" after you are done submitting answers for a '
						. 'student.  Leaving this permission on is dangerous, as you could unintentionally submit '
						. 'answers for a student, which can use up their total number of attempts.  Further, if you '
						. 'are viewing an open test version, your answers on each page will be saved when you move '
						. q/between pages, which will overwrite the student's saved answers./
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{report_bugs}',
				doc  => x('Can report bugs'),
				doc2 => x(
					'Users with at least this permission level get a link in the left panel for reporting bugs to the '
						. 'bug tracking system at bugs.webwork.maa.org.'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{change_name}',
				doc  => x('Allowed to change their name'),
				doc2 => x(
					'Users at this level and higher are allowed to change their first and last name. '
						. 'Note that if WeBWorK is used with an LMS, it may be configured to allow the LMS to '
						. 'manage user data such as user names. Then if a user changes their name in WeBWorK, '
						. 'the LMS might override that later. This course might be configured to allow you to '
						. 'control whether or not the LMS is allowed to manage user date in the LTI tab of the '
						. 'Course Configuration page.'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{change_email_address}',
				doc  => x('Allowed to change their email address'),
				doc2 => x(
					'Users at this level and higher are allowed to change their email address. Normally guest '
						. 'users are not allowed to change the email address since it does not make sense to send '
						. 'email to anonymous accounts.'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{change_pg_display_settings}',
				doc  => x('Allowed to change display settings used in pg problems'),
				doc2 => x(
					'Users at this level and higher are allowed to change display settings used in pg problems.'
						. 'Note that if it is expected that there will be students that have vision impairments and '
						. 'MathQuill is enabled to assist with answer entry, then you should not set this '
						. 'permission to a level above student as those students may need to disable MathQuill.'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{view_answers}',
				doc  => x('Allowed to view past answers'),
				doc2 => x('These users and higher get the "Show Past Answers" button on the problem page.'),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{view_unopened_sets}',
				doc  => x('Allowed to view problems in sets which are not open yet'),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{show_correct_answers_before_answer_date}',
				doc  => x('Allowed to see the correct answers before the answer date'),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{show_solutions_before_answer_date}',
				doc  => x('Allowed to see solutions before the answer date'),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{can_show_old_answers}',
				doc  => x('Can show old answers'),
				doc2 => x(
					'When viewing a problem, WeBWorK usually puts the previously submitted answer in the answer '
						. 'blank. Below this level, old answers are never shown. Typically, that is the desired '
						. 'behaviour for guest accounts.'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{navigation_allowed}',
				doc  => x('Allowed to view course home page'),
				doc2 => x(
					'If a user does not have this permission, then the user will not be allowed to navigate to the '
						. 'course home page, i.e., the Assignments page. This should only be used for a course when LTI '
						. 'authentication is used, and is most useful when LTIGradeMode is set to homework. In this case '
						. 'the Assignments page is not useful and can even be confusing to students. To use this feature '
						. 'set this permission to "login_proctor".'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{view_leaderboard}',
				doc  => x('Allowed to view achievements leaderboard'),
				doc2 => x(
					'The permission level to view the achievements leaderboard, if achievements are enabled. '
						. 'Consider that achievement points can be closely tied to student grades before '
						. 'showing the leaderboard to students.'
				),
				type => 'permission'
			},
			{
				var  => 'permissionLevels{view_leaderboard_usernames}',
				doc  => x('Allowed to view usernames on the achievements leaderboard'),
				doc2 => x(
					'The permission level to view usernames on the achievements leaderboard. '
						. 'Consider that achievement points can be closely tied to student grades before '
						. 'showing user names to students.'
				),
				type => 'permission'
			},
		],
		[
			x('Problem Display/Answer Checking'),
			{
				var  => 'pg{displayModes}',
				doc  => x('List of display modes made available to students'),
				doc2 => x(
					'<p>When viewing a problem, users may choose different methods of rendering formulas via an '
						. 'options box in the left panel. Here, you can adjust what display modes are listed.</p>'
						. '<p>The display modes are</p><ul><li>plainText: shows the raw LaTeX strings for formulas.'
						. '</li><li>images: produces images using the external programs LaTeX and dvipng.</li>'
						. '<li>MathJax: uses javascript to render mathematics.</li></ul><p>You must use at least '
						. 'one display mode. If you select only one, then the options box will not give a choice of '
						. 'modes (since there will only be one active).</p>'
				),
				min    => 1,
				values => [ 'MathJax', 'images', 'plainText' ],
				type   => 'checkboxlist'
			},
			{
				var  => 'pg{options}{displayMode}',
				doc  => x('The default display mode'),
				doc2 => x(
					'Enter one of the allowed display mode types above. See \'display modes entry\' for descriptions.'),
				min    => 1,
				values => [qw(MathJax images plainText)],
				type   => 'popuplist'
			},
			{
				var  => 'pg{specialPGEnvironmentVars}{entryAssist}',
				doc  => x('Assist with the student answer entry process.'),
				doc2 => x(
					'<p>MathQuill renders students answers in real-time as they type on the keyboard.</p><p>MathView '
						. 'allows students to choose from a variety of common math structures (such as fractions and '
						. 'square roots) as they attempt to input their answers.</p>'
				),
				min    => 1,
				values => [qw(None MathQuill MathView)],
				type   => 'popuplist'
			},
			{
				var  => 'pg{options}{showEvaluatedAnswers}',
				doc  => x('Display the evaluated student answer'),
				doc2 => x(
					'Set to true to display the "Entered" column which automatically shows the evaluated student '
						. 'answer, e.g., 1 if student input is sin(pi/2). If this is set to false, e.g., to save '
						. 'space in the response area, the student can still see their evaluated answer by clicking '
						. 'on the typeset version of their answer.'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{ansEvalDefaults}{useBaseTenLog}',
				doc  => x('Use log base 10 instead of base <i>e</i>'),
				doc2 => x('Set to true for log to mean base 10 log and false for log to mean natural logarithm.'),
				type => 'boolean'
			},
			{
				var  => 'pg{specialPGEnvironmentVars}{useOldAnswerMacros}',
				doc  => x('Use older answer checkers'),
				doc2 => x(
					'<p>During summer 2005, a newer version of the answer checkers was implemented for answers '
						. 'which are functions and numbers. The newer checkers allow more functions in student '
						. 'answers, and behave better in certain cases. Some problems are specifically coded to '
						. 'use new (or old) answer checkers. However, for the bulk of the problems, you can '
						. 'choose what the default will be here.</p><p>Choosing <i>false</i> here means that the '
						. 'newer answer checkers will be used by default, and choosing <i>true</i> means that the '
						. 'old answer checkers will be used by default.</p>'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{specialPGEnvironmentVars}{parseAlternatives}',
				doc  => x('Allow Unicode alternatives in student answers'),
				doc2 => x(
					'Set to true to allow students to enter Unicode versions of some characters (like U+2212 for the '
						. 'minus sign) in their answers. One reason to allow this is that copying and pasting output '
						. 'from MathJax can introduce these characters, but it is also getting easier to enter these '
						. 'characters directory from the keyboard.'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{specialPGEnvironmentVars}{convertFullWidthCharacters}',
				doc  => x('Automatically convert Full Width Unicode characters to their ASCII equivalents'),
				doc2 => x(
					'Set to true to have Full Width Unicode character (U+FF01 to U+FF5E) converted to their ASCII '
						. 'equivalents (U+0021 to U+007E) automatically in MathObjects. This may be valuable for '
						. 'Chinese keyboards, for example, that automatically use Full Width characters for '
						. 'parentheses and commas.'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{ansEvalDefaults}{numRelPercentTolDefault}',
				doc  => x('Allowed error, as a percentage, for numerical comparisons'),
				doc2 => x(
					'When numerical answers are checked, most test if the student\'s answer is close enough to the '
						. 'programmed answer be computing the error as a percentage of the correct answer. This '
						. 'value controls the default for how close the student answer has to be in order to be '
						. 'marked correct.<p>A value such as 0.1 means 0.1 percent error is allowed.</p>'
				),
				type => 'number'
			},
			{
				var  => 'pg{specialPGEnvironmentVars}{waiveExplanations}',
				doc  => x('Skip explanation essay answer fields'),
				doc2 => x(
					'Some problems have an explanation essay answer field, typically following a simpler answer '
						. 'field. For example, find a certain derivative using the definition. An answer blank '
						. 'would be present for the derivative to be automatically checked, and then there would '
						. 'be a separate essay answer field to show the steps of actually using the definition of '
						. 'the derivative, to be scored manually. With this setting, the essay explanation fields '
						. 'are supperessed. Instructors may use the exercise without incurring the manual grading.'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{options}{showHintsAfter}',
				doc  => x('Default number of attempts before hints are shown in a problem (-1 => hide hints)'),
				doc2 => x(
					'This is the default number of attempts a student must make before hints will be shown to the '
						. 'student. Set this to -1 to hide hints. Note that this can be overridden with a per '
						. 'problem setting.'
				),
				type => 'number'
			},
			{
				var  => 'problemGraderScore',
				doc  => x('Method to enter problem scores in the single problem manual grader'),
				doc2 => x(
					'This configures if the single problem manual grader has inputs to enter problem scores as '
						. 'a percent, a point value, or both. Note, the problem score is always saved as a '
						. 'percent, so when using a point value, the problem score will be rounded to the '
						. 'nearest whole percent.'
				),
				values => [qw(Percent Point Both)],
				type   => 'popuplist'
			},
			{
				var  => 'pg{options}{enterKey}',
				doc  => x('Enter Key Behavior'),
				doc2 => x(
					'If this is set to "preview", hitting the enter key on a homework problem page activates the '
						. '"Preview My Answers" button. If this is set to "submit", then the enter key activates '
						. 'the "Submit Answers" button instead. Or if that button is not present, it will activate '
						. 'the "Check Answers" button. Or if that button is also not present, it will activate '
						. 'the "Preview My Answers" button. A third option is "conservative". In this case, the '
						. 'enter key behaves like "preview" when the "Submit" button is available and there are '
						. 'only finitely many attempts allowed. Otherise the enter key behaves like "submit". '
						. 'Note that this is only affects homework problem pages, not test/quiz pages, and not '
						. 'instructor pages like the PG Editor and the Library Browser.'
				),
				type   => 'popuplist',
				values => [ 'preview', 'submit', 'conservative' ]
			},
			{
				var  => 'pg{options}{automaticAnswerFeedback}',
				doc  => x('Show automatic answer feedback'),
				doc2 => x(
					'Answer feedback will be available in problems when returning to a previously worked problem and '
						. 'after answers are available. Students will not need to click "Submit Answers" to make this '
						. 'feedback appear. Furthermore, the $showPartialCorrectAnswers variable set in some problems '
						. 'that prevents showing which of the answers are correct is ignored after the answer date.'
				),
				type => 'boolean'
			},
			{
				var  => 'pg{options}{correctRevealBtnAlways}',
				doc  => x('Show correct answer "Reveal" button always'),
				doc2 => x(
					'A "Reveal" button must be clicked to make a correct answer visible any time that correct '
						. 'answers for a problem are shown. Note that this is always the case for instructors '
						. 'before answers are available to students, and in "Show Me Another" problems.'
				),
				type => 'boolean'
			}
		],
		[
			x('E-Mail'),
			{
				var  => 'mail{feedbackSubjectFormat}',
				doc  => x('Format for the subject line in feedback emails'),
				doc2 => x(
					'When students click the <em>Email Instructor</em> button to send feedback, WeBWorK fills in the '
						. 'subject line. Here you can set the subject line. In it, you can have various bits of '
						. 'information filled in with the following escape sequences.<p><ul><li>%c = course ID</li>'
						. '<li>%u = user ID</li><li>%s = set ID</li><li>%p = problem ID</li><li>%x = section</li>'
						. '<li>%r = recitation</li><li>%% = literal percent sign</li></ul>'
				),
				width => 45,
				type  => 'text'
			},
			{
				var  => 'mail{feedbackVerbosity}',
				doc  => x('E-mail verbosity level'),
				doc2 => x(
					'The email verbosity level controls how much information is automatically added to feedback '
						. 'emails. Levels are<ol><li> Simple: send only the feedback comment and context link</li>'
						. '<li> Standard: as in Simple, plus user, set, problem, and PG data</li>'
						. '<li> Debug: as in Standard, plus the problem environment (debugging data)</li></ol>'
				),
				labels => {
					'0' => x('Simple'),
					'1' => x('Standard'),
					'2' => x('Debug')
				},
				values => [qw(0 1 2)],
				type   => 'popuplist'

			},
			{
				var  => 'permissionLevels{receive_feedback}',
				doc  => x('Permission levels for receiving feedback email'),
				doc2 => x(
					'Users with these permission levels will be sent feedback emails from students when they use the '
						. 'feedback button.'
				),
				type => 'permission_checkboxlist',
			},
			{
				var  => 'mail{feedbackRecipients}',
				doc  => x('Additional addresses for receiving feedback email'),
				doc2 => x(
					'By default, feedback is sent to all users above who have permission to receive feedback. Feedback '
						. 'is also sent to any addresses specified here. Separate email address entries with commas.'
				),
				type => 'list'
			},
			{
				var  => 'feedback_by_section',
				doc  => x('Feedback by Section.'),
				doc2 => x(
					'By default, feedback is always sent to all users specified to receive feedback. This '
						. 'variable sets the system to only email feedback to users who have the same section as '
						. 'the user initiating the feedback. I.e., feedback will only be sent to section leaders.'
				),
				type => 'boolean'
			},
		],
	];

	# These are the LTI authentication variables that may be added to the 'LTI' tab on the Course Configuration page.
	# These are added if the variables near the end of authen_LTI.conf are set.
	my $LTIConfigValues = {
		'LTI{v1p1}{LMS_name}' => {
			var  => 'LTI{v1p1}{LMS_name}',
			doc  => x('The name of the LMS'),
			doc2 => x(
				'The name of the LMS. This is used in messages to users that direct them to go back to '
					. 'the LMS to access something in the WeBWorK course.'
			),
			type => 'text'
		},
		'LTI{v1p1}{LMS_url}' => {
			var  => 'LTI{v1p1}{LMS_url}',
			doc  => x('URL for the LMS'),
			doc2 => x(
				'An address that can be used to log in to the LMS. This is used in messages to users '
					. 'that direct them to go back to the LMS to access something in the WeBWorK course.'
			),
			type  => 'text',
			width => 30,
		},
		external_auth => {
			var  => 'external_auth',
			doc  => x('Require users to log in through the LMS'),
			doc2 => x(
				'If this is set, all users (including the instructor) must enter the WeBWorK course through the LMS. '
					. 'If a user reaches the regular WeBWorK login screen, they receive a message directing them '
					. 'back to the LMS.'
			),
			type => 'boolean'
		},
		LTIGradeMode => {
			var  => 'LTIGradeMode',
			doc  => x('Grade passback mode'),
			doc2 => x(
				'Sets how grades will be passed back from WeBWorK to the LMS.<dl><dt>course</dt><dd>Sends a single '
					. 'grade back to the LMS. This grade is calculated out of the total question set that has been '
					. 'assigned to a user and made open. Therefore it can appear low, since it counts problem sets '
					. 'with future due dates as zero.</dd> <dt>homework</dt><dd>Sends back a score for each problem '
					. 'set (including for each quiz). To use this, the external links from the LMS must be problem '
					. 'set specific. For example, <code>webwork.myschool.edu/webwork2/course-name/problem_set_name'
					. '</code>. If the problem set name has space characters, they should be underscores in these '
					. 'addresses. Also, to initialize the communication between WeBWorK and the LMS, the user must '
					. 'follow each of these external learning tools at least one time. Since there must be a '
					. 'separate external tool link for each problem set, this option requires more maintenance '
					. 'of the LMS course.</dd></dl>'
			),
			values => [ '', qw(course homework) ],
			labels => { '' => x('None'), 'course' => x('Course'), 'homework' => x('Homework') },
			type   => 'popuplist'
		},
		LTICheckPrior => {
			var  => 'LTICheckPrior',
			doc  => x('Check a score in the LMS actually needs updating before updating it'),
			doc2 => x(
				'<p>When this is true, any time WeBWorK is about to send a score to the LMS, it will first request '
					. 'from the LMS what that score currently is. Then if there is no significant difference between '
					. 'the LMS score and the WeBWorK score, WeBWorK will not follow through with updating the LMS '
					. 'score. This is to avoid frequent insignificant updates to a student score in the LMS. With some '
					. 'LMSs, students may receive notifications each time a score is updated, and setting this '
					. 'variable will prevent too many notifications for them. This does create a two-step process, '
					. 'first querying the current score from the LMS and then actually updating the score (if there is '
					. 'a significant difference). Additional details:</p><ul><li>If the LMS score is not 100%, but the '
					. 'WeBWorK score is, then even if the LMS score is only insignificantly less than 100%, it will be '
					. 'updated anyway.</li><li>If the LMS score is not set and the WeBWorK score is 0, this is '
					. 'considered a significant difference and the LMS score will updated to 0. However, the '
					. 'constraints of the $LTISendScoresAfterDate and the $LTISendGradesEarlyThreshold variables '
					. '(described below) might apply, and the score may still not be updated in this case.</li>'
					. '<li>"Significant" means an absolute difference of 0.001, or 0.1%. At this time this is not '
					. 'configurable.</li></ul>'
			),
			type => 'boolean'
		},
		LTIGradeOnSubmit => {
			var  => 'LTIGradeOnSubmit',
			doc  => x('Update LMS Grade Each Submit'),
			doc2 => x(
				'If this is set to true, then  each time a user submits an answer or grades a test, that will trigger '
					. 'WeBWorK possibly reporting a score to the LMS. See $LTICheckPrior for one reason that WeBWorK '
					. 'might not ultimately send a score. But there are other reasons too. WeBWorK will send the score '
					. "(the assignment's score if \$LTIGradeMode is 'homework' or the overall course score if "
					. "\$LTIGradeMode is 'course') to the LMS only if either the assignment's "
					. "\$LTISendGradesEarlyThreshold has been met or if it is past that assignment's "
					. '$LTISendScoresAfterDate.'
			),
			type => 'boolean'
		},
		LTISendScoresAfterDate => {
			var  => 'LTISendScoresAfterDate',
			doc  => x('Date after which scores will be sent to the LMS'),
			doc2 => x(
				'<p>This can be set to one of the dates associated with assignments, or "Never". For each assignment, '
					. 'if this setting is "After the ... " then if it is after the indicated date, WeBWorK will send '
					. 'scores. If this setting is "Never" then there is no date that will force WeBWorK to send scores '
					. 'and only the $LTISendGradesEarlyThreshold can cause scores to be sent. If scores are sent:</p> '
					. "<ul><li>For 'course' grade passback mode, the assignment will be included in the overall course "
					. "score calculation.</li><li>For 'homework' grade passback mode, the assignment's score itself "
					. 'will be sent.</li></ul><p>If $LTISendScoresAfterDate is set to "After the reduced scoring date" '
					. 'and an assignment has no reduced scoring date or reduced scoring is disabled, the fallback is '
					. 'to use the close date.</p><p>For a given assignment, WeBWorK will still send a score to the LMS '
					. 'if the $LTISendGradesEarlyThreshold has been met, regardless of how $LTISendScoresAfterDate is '
					. 'set.</p>'
			),
			values => [qw(open_date reduced_scoring_date due_date answer_date never)],
			labels => {
				open_date            => x('After the open date'),
				reduced_scoring_date => x('After the reduced scoring date'),
				due_date             => x('After the close date'),
				answer_date          => x('After the answer date'),
				never                => x('Never')
			},
			type => 'popuplist'
		},
		LTISendGradesEarlyThreshold => {
			var  => 'LTISendGradesEarlyThreshold',
			doc  => x('Condition under which scores will be sent early to an LMS'),
			doc2 => x(
				"<p>This can either be set to a score or set to Attempted. When something triggers a potential grade "
					. 'passback, if it is earlier than $LTISendScoresAfterDate, the condition described by this '
					. 'variable must be met or else no score will be sent.</p><p>If this variable is a score, then the '
					. 'set will need to have a score that reaches or exceeds this score for its score to be sent to '
					. "the LMS (or included in the 'course' score calculation). If this variable is set to Attempted, "
					. 'then the set needs to have been attempted for its score to be sent to the LMS (or included in '
					. "the 'course' score calculation).</p><p>For a regular or jitar set, 'attempted' means that at "
					. "least one exercise was attempted. For a test, 'attempted' means that either multiple versions "
					. 'exist or there is one version with a graded submission.</p>'
			),
			values => [ qw(
				attempted 0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1
			) ],
			labels => {
				attempted => x('Attempted'),
				0         => '0%',
				0.05      => '5%',
				0.1       => '10%',
				0.15      => '15%',
				0.2       => '20%',
				0.25      => '25%',
				0.3       => '30%',
				0.35      => '35%',
				0.4       => '40%',
				0.45      => '45%',
				0.5       => '50%',
				0.55      => '55%',
				0.6       => '60%',
				0.65      => '65%',
				0.7       => '70%',
				0.75      => '75%',
				0.8       => '80%',
				0.85      => '85%',
				0.9       => '90%',
				0.95      => '95%',
				1         => '100%',
			},
			type => 'popuplist'
		},
		LTIMassUpdateInterval => {
			var  => 'LTIMassUpdateInterval',
			doc  => x('Time in seconds to periodically update LMS grades (-1 to disable)'),
			doc2 => x(
				'Sets the time in seconds to periodically update the LMS scores. WeBWorK will update all scores on '
					. 'the LMS if it has been longer than this time since the completion of the last update. This is '
					. 'only an approximate time. Mass updates of this nature may put significant strain on the server, '
					. 'and should not be set to happen too frequently. -1 disables these periodic updates.'
			),
			type => 'number'
		},
		LMSManageUserData => {
			var  => 'LMSManageUserData',
			doc  => x('Allow the LMS to update user account data'),
			doc2 => x(
				'If this is set to true, then when a user enters WeBWorK using LTI from an LMS, their user account '
					. 'data in WeBWorK will be updated to match the data from the LMS.  This applies to first name, '
					. 'last name, section, recitation, and email address.  If a user\'s information changes in the LMS '
					. 'then it will change in WeBWorK the next time the user enters WeBWorK from the LMS.  Any changes '
					. 'to the user data that are made in WeBWorK will be overwritten.  So if this is set to true, you '
					. 'may want to review the settings in the Permissions tab for who is allowed to change their own '
					. 'name and email address.'
			),
			type => 'boolean'
		},
		'LTI{v1p1}{BasicConsumerSecret}' => {
			var  => 'LTI{v1p1}{BasicConsumerSecret}',
			doc  => x('LMS shared secret for LTI 1.1 authentication'),
			doc2 => x(
				'This secret word is used to validate logins from an LMS using LTI 1.1. '
					. 'This secret word must match the word configured in the LMS.'
			),
			type   => 'text',
			secret => 1
		},
		'LTI{v1p3}{PlatfromID}' => {
			var    => 'LTI{v1p3}{PlatformID}',
			doc    => x('LMS platform ID for LTI 1.3'),
			doc2   => x('LMS platform ID used to validate logins from an LMS using LTI 1.3.'),
			type   => 'text',
			secret => 1
		},
		'LTI{v1p3}{ClientID}' => {
			var    => 'LTI{v1p3}{ClientID}',
			doc    => x('LMS client ID for LTI 1.3'),
			doc2   => x('LMS client ID used to validate logins from an LMS using LTI 1.3.'),
			type   => 'text',
			secret => 1
		},
		'LTI{v1p3}{DeploymentID}' => {
			var    => 'LTI{v1p3}{DeploymentID}',
			doc    => x('LMS deployment ID for LTI 1.3'),
			doc2   => x('LMS deployment ID used to validate logins from an LMS using LTI 1.3.'),
			type   => 'text',
			secret => 1
		},
		'LTI{v1p3}{PublicKeysetURL}' => {
			var    => 'LTI{v1p3}{PublicKeysetURL}',
			doc    => x('LMS public keyset URL for LTI 1.3'),
			doc2   => x('LMS public keyset URL used to validate logins from an LMS using LTI 1.3.'),
			type   => 'text',
			secret => 1
		},
		'LTI{v1p3}{AccessTokenURL}' => {
			var    => 'LTI{v1p3}{AccessTokenURL}',
			doc    => x('LMS access token URL for LTI 1.3'),
			doc2   => x('LMS access token URL used to validate logins from an LMS using LTI 1.3.'),
			type   => 'text',
			secret => 1
		},
		'LTI{v1p3}{AccessTokenAUD}' => {
			var    => 'LTI{v1p3}{AccessTokenAUD}',
			doc    => x('LMS access token AUD for LTI 1.3'),
			doc2   => x('LMS access token AUD used to validate logins from an LMS using LTI 1.3.'),
			type   => 'text',
			secret => 1
		},
		'LTI{v1p3}{AuthReqURL}' => {
			var    => 'LTI{v1p3}{AuthReqURL}',
			doc    => x('LMS authorization request URL for LTI 1.3'),
			doc2   => x('LMS authorization request URL used to validate logins from an LMS using LTI 1.3.'),
			type   => 'text',
			secret => 1
		},
		debug_lti_parameters => {
			var  => 'debug_lti_parameters',
			doc  => x('Show LTI parameters (for debugging)'),
			doc2 => x(
				'When this is true, then when a user enters WeBWorK from an external tool link in the LMS, '
					. 'the bottom of the screen will display the data that the LMS passed to WeBWorK. This may '
					. 'be useful to debug LTI, especially because different LMS systems have different parameters.'
			),
			type => 'boolean'
		},
		lms_context_id => {
			var  => 'lms_context_id',
			doc  => x('LMS Context ID'),
			doc2 => x(
				'This must be set in order to utilize LTI content selection. The WeBWorK content item URL must be '
					. 'set for the external tool in the LMS first. Then if content selection from the LMS is '
					. 'attempted, you will be shown the LMS context ID. Enter the context ID shown here, and then '
					. 'you will be able to select assignments from this course, and import them into the LMS.'
			),
			type => 'lms_context_id'
		}
	};

	# Get the list of theme folders in the theme directory.
	my $themes = eval { path($ce->{webworkDirs}{themes})->list({ dir => 1 })->map('basename')->sort; };
	die "can't opendir $ce->{webworkDirs}{themes}: $@" if $@;

	# Get the list of all site hardcopy theme files.
	my $hardcopyThemesSite =
		eval { path($ce->{webworkDirs}{hardcopyThemes})->list->grep(qr/\.xml$/)->map('basename')->sort };
	die "Unabled to list files in  $ce->{webworkDirs}{hardcopyThemes}: $@" if $@;

	my $hardcopyThemesCourse = eval {
		path($ce->{courseDirs}{hardcopyThemes})->list->grep(sub {
			/\.xml$/
				&& eval {
					# Check that the file is valid XML.
					XML::LibXML->load_xml(location => $_->to_string);
					1;
				};
		})->map('basename');
	} || [];

	# Get unique file names, merging lists from site and course folders.
	my $hardcopyThemes = [
		sort(do {
			my %seen;
			grep { !$seen{$_}++ } (@$hardcopyThemesSite, @$hardcopyThemesCourse);
		})
	];

	# Get enabled site themes plus all course themes.
	my $hardcopyThemesAvailable = [
		sort(do {
			my %seen;
			grep { !$seen{$_}++ } @{ $ce->{hardcopyThemes} }, @$hardcopyThemesCourse;
		})
	];

	# Get list of localization dictionaries.
	my $languages = eval {
		my %seen;
		path($ce->{webworkDirs}{localize})->list->grep(qr/\.mo$|\.po$/)->map(sub { $_->basename =~ s/\.[pm]o$//r })
			->grep(sub { !$seen{$_}++ });
	};
	die "Unable to list files in $ce->{webworkDirs}{localize}: $@" if $@;

	for my $oneConfig (@$configValues) {
		for my $item (@$oneConfig) {
			next unless ref($item) eq 'HASH';

			$item->{values} = $themes if $item->{var} eq 'defaultTheme';
			$item->{values} = $hardcopyThemesAvailable
				if $item->{var} eq 'hardcopyTheme' || $item->{var} eq 'hardcopyThemePGEditor';
			$item->{values} = $hardcopyThemesSite if $item->{var} eq 'hardcopyThemes';

			$item->{values} = $languages if $item->{var} eq 'language';
		}
	}

	if ($ce->{LTIVersion} && ref($ce->{LTIConfigVariables}) eq 'ARRAY' && @{ $ce->{LTIConfigVariables} }) {
		if ($ce->{LTIVersion} eq 'v1p3') {
			$LTIConfigValues->{'LTI{v1p3}{LMS_name}'} =
				{ %{ delete $LTIConfigValues->{'LTI{v1p1}{LMS_name}'} }, var => 'LTI{v1p3}{LMS_name}' };
			$LTIConfigValues->{'LTI{v1p3}{LMS_url}'} =
				{ %{ delete $LTIConfigValues->{'LTI{v1p1}{LMS_url}'} }, var => 'LTI{v1p3}{LMS_url}' };
			delete $LTIConfigValues->{'LTI{v1p1}{BasicConsumerSecret}'};
		} else {
			for my $key (
				'PlatformID',     'ClientID',       'DeploymentID', 'PublicKeysetURL',
				'AccessTokenURL', 'AccessTokenAUD', 'AuthReqURL'
				)
			{
				delete $LTIConfigValues->{"LTI{v1p3}{$key}"};
			}
		}

		push(
			@$configValues,
			[
				x('LTI'),
				map { $LTIConfigValues->{$_} }
					grep { defined $LTIConfigValues->{$_} } @{ $ce->{LTIConfigVariables} }
			]
		);
	}

	return $configValues;
}

1;
