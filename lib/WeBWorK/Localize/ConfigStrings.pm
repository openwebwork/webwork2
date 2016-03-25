package WeBWorK::Localize::ConfigStrings;

# This is a dummy perl file.  It is not compiled or used anywhere.  Its sole
# purpose is to have the config strings wrapped in the x function so
# that they will be included in webwork2.pot when xgettext.pl is run.  

$ConfigValues = [
    [x('General'),
		{ var => 'courseFiles{course_info}',
		  doc => x('Name of course information file'),
		  doc2 => x('The name of course information file (located in the templates directory). Its contents are displayed in the right panel next to the list of homework sets.'),
		  type => 'text'
		},
		{ 
		  var => 'defaultTheme',
		  doc => x('Theme (refresh page after saving changes to reveal new theme.)'),
		  doc2 => x('There are currently two themes (or skins) to choose from: math3 and math4.  The theme specifies a unified look and feel for the WeBWorK course web pages.'),
		  values => [qw(math3 math4)],
		  type => 'popuplist',
		  hashVar => '{defaultTheme}'
		},
		  { var => 'language',
		  doc => x('Language (refresh page after saving changes to reveal new language.)'),
		  doc2 => x('WeBWorK currently has translations for four languages: "English en", "Turkish tr", "Spanish es", and "French fr" '),
		  values => [qw(en tr es fr zh_hk heb)],
		  type => 'popuplist'
		},
		{ var => 'sessionKeyTimeout',
		  doc => x('Inactivity time before a user is required to login again'),
		  doc2 => x('Length of time, in seconds, a user has to be inactive before he is required to login again.<p> This value should be entered as a number, so as 3600 instead of 60*60 for one hour'),
		  type => 'number'
		},
		{ var => 'siteDefaults{timezone}',
		  doc => x('Timezone for the course'),
		  doc2 => x('Some servers handle courses taking place in different timezones.  If this course is not showing the correct timezone, enter the correct value here.  The format consists of unix times, such as "America/New_York","America/Chicago", "America/Denver", "America/Phoenix" or "America/Los_Angeles". Complete list: <a href="http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones">TimeZoneFiles</a>'),
		  type => 'timezone',
		  hashVar => '{siteDefaults}->{timezone}'
		},
     		{ 
		  var => 'hardcopyTheme',
		  doc => x('Hardcopy Theme'),
		  doc2 => x('There are currently two hardcopy themes to choose from: One Column and Two Columns.  The Two Columns theme is the traditional hardcopy format.  The One Column theme uses the full page width for each column'),
		  values => $hardcopyThemes,
		  labels => $hardcopyThemeNames,
		  type => 'popuplist',
		  hashVar => '{hardcopyTheme}'
		},
        { var => 'options{useDateTimePicker}',
          doc => x('Use Date Picker'),
          doc2 => x('Enables the use of the date picker on the Homework Sets Editor 2 page and the Problem Set Detail page'),
          type => 'boolean'
	},
        { var => 'showCourseHomeworkTotals',
        	  doc => x('Show Total Homework Grade on Grades Page'),
       		  doc2 => x('When this is on students will see a line on the Grades page which has their total cumulative homework score.  This score includes all sets assigned to the student.'),
          	  type => 'boolean'
	},

            { var => 'pg{options}{enableProgressBar}',
        	  doc => x('Enable Progress Bar and current problem highlighting'),
       		  doc2 => x('A switch to govern the use of a Progress Bar for the student; this also enables/disables the highlighting of the current problem in the side bar, and whether it is correct (&#x2713;), in progress (&hellip;), incorrect (&#x2717;), or unattempted (no symbol).'),
          	  type => 'boolean'
	},
	 { 	var => 'pg{timeAssignDue}',
		doc => x('Default Time that the Assignment is Due'),
		doc2 => x('The time of the day that the assignment is due.  This can be changed on an individual basis, but WeBWorK will use this value for default when a set is created.'),
		type => 'time',
		hashVar => '{pg}->{timeAssignDue}'
	 },
	 {	var => 'pg{assignOpenPriorToDue}',
		doc => x('Default Amount of Time (in minutes) before Due Date that the Assignment is Open'),
		doc2 => x('The amount of time (in minutes) before the due date when the assignment is opened.  You can change this for individual homework, but WeBWorK will use this value when a set is created. '),
		type => 'number',
		hashVar => '{pg}->{assignOpenPriorToDue}'
	 },
	 {	var => 'pg{answersOpenAfterDueDate}',
		doc => x('Default Amount of Time (in minutes) after Due Date that Answers are Open'),
		doc2 => x('The amount of time (in minutes) after the due date that the Answers are available to student to view.  You can change this for individual homework, but WeBWorK will use this value when a set is created.'),
		type => 'number',
		hashVar => '{pg}->{answersOpenAfterDueDate}'
	 },
    ],
	[x('Optional Modules'),
    	{ var => 'achievementsEnabled',
		  doc => x('Enable Course Achievements'),
		  doc2 => x('Activiating this will enable Mathchievements for webwork.  Mathchievements can be managed by using the Achievement Editor link.'),
		  type => 'boolean'
		  },                
		 { var => 'achievementPointsPerProblem',
		  doc => x('Achievement Points Per Problem'),
		  doc2 => x('This is the number of achievement points given to each user for completing a problem.'),
		  type => 'number'
		  },
     	 { var => 'achievementItemsEnabled',
		  doc => x('Enable Achievement Items'),
		  doc2 => x('Activiating this will enable achievement items. This features rewards students who earn achievements with items that allow them to affect their homework in a limited way.'),
		  type => 'boolean'
	 },
	         { var => 'options{enableConditionalRelease}',
          doc => x('Enable Conditional Release'),
          doc2 => x('Enables the use of the conditional release system.  To use conditional release you need to specify a list of set names on the Problem Set Detail Page, along with a minimum score.  Students will not be able to access that homework set until they have achieved the minimum score on all of the listed sets.'),
          type => 'boolean'
	},
		{ var => 'pg{ansEvalDefaults}{enableReducedScoring}',
		  doc => x('Enable Reduced Scoring'),
		  doc2 => x('This sets whether the Reduced Scoring system will be enabled.  If enabled you will need to set the default length of the reduced scoring period and the value of work done in the reduced scoring period below.  <p> To use this, you also have to enable Reduced Scoring for individual assignments and set their Reduced Scoring Dates by editing the set data.<p> This works with the avg_problem_grader (which is the the default grader) and the  std_problem_grader (the all or nothing grader).  It will work with custom graders if they are written appropriately.'),
		  type => 'boolean'
		},
		{ var => 'pg{ansEvalDefaults}{reducedScoringValue}',
		  doc => x('Value of work done in Reduced Scoring Period'),
		  doc2 => x('<p>After the Reduced Scoring Date all additional work done by the student counts at a reduced rate. Here is where you set the reduced rate which must be a percentage. For example if this value is 50% and a student views a problem during the Reduced Scoring Period, they will see the message "You are in the Reduced Scoring Period: All additional work done counts 50% of the original." </p><p>To use this, you also have to enable Reduced Scoring and set the Reduced Scoring Date for individual assignments by editing the set data using the Hmwk Sets Editor.</p><p>This works with the avg_problem_grader (which is the the default grader) and the std_problem_grader (the all or nothing grader). It will work with custom graders if they are written appropriately.</p>'),
		  labels=>{'0.1' => '10%',
			   '0.15' => '15%',
			   '0.2' => '20%',
			   '0.25' => '25%',
			   '0.3' => '30%',
			   '0.35' => '35%',
			   '0.4' => '40%',
			   '0.45' => '45%',
			   '0.5' => '50%',
			   '0.55' => '55%',
			   '0.6' => '60%',
			   '0.65' => '65%',
			   '0.7' => '70%',
			   '0.75' => '75%',
			   '0.8' => '80%',
			   '0.85' => '85%',
			   '0.9' => '90%',
			   '0.95' => '95%',
			   '1' => '100%'},
		  values => [qw(1 0.95 0.9 0.85 0.8 0.75 0.7 0.65 0.6 0.55 0.5 0.45 0.4 0.35 0.3 0.25 0.2 0.15 0.1)],
		  type => 'popuplist'
		},
	 { var => 'pg{ansEvalDefaults}{reducedScoringPeriod}',
	   doc => x('Default Length of Reduced Scoring Period in minutes'),
	   doc2 => x('The Reduced Scoring Period is the default period before the due date during which all additional work done by the student counts at a reduced rate. When enabling reduced scoring for a set the reduced scoring date will be set to the due date minus this number. The reduced scoring date can then be changed. If the Reduced Scoring is enabled and if it is after the reduced scoring date, but before the due date, a message like "This assignment has a Reduced Scoring Period that begins 11/08/2009 at 06:17pm EST and ends on the due date, 11/10/2009 at 06:17pm EST. During this period all additional work done counts 50% of the original." will be displayed.'),
	   type => 'number'
	 },
	 { var => 'pg{options}{enableShowMeAnother}',
	   doc => x('Enable Show Me Another button'),
	   doc2 => x('Enables use of the Show Me Another button, which offers the student a newly-seeded version of the current problem, complete with solution (if it exists for that problem).'),
	   type => 'boolean'
	 },
	 { var => 'pg{options}{showMeAnotherMaxReps}',
	   doc => x('Maximum times Show me Another can be used per problem (-1 => unlimited)'),
	   doc2 => x('The Maximum number of times Show me Another can be used per problem by a student. If set to -1 then there is no limit to the number of times that Show Me Another can be used.'),
	   type => 'number'
	 },
	 { var => 'pg{options}{showMeAnother}',
	   doc => x('List of options for Show Me Another button'),
	   doc2 => x('<ul><li><b>SMAcheckAnswers</b>: enables the Check Answers button <i>for the new problem</i> when Show Me Another is clicked</li> <li><b>SMAshowSolutions</b>: shows walk-through solution <i>for the new problem</i> when Show Me Another is clicked; a check is done first to make sure that a solution exists </li><li><b>SMAshowCorrect</b>: correct answers <i>for the new problem</i> can be viewed when Show Me Another is clicked; note that <b>SMAcheckAnswers</b> needs to be enabled at the same time</li><li><b>SMAshowHints</b>: show hints <i>for the new problem</i> (assuming they exist)</li></ul>Note: there is very little point enabling the button unless you check at least one of these options - the students would simply see a new version that they can not attempt or learn from.</p>'),
	   min  => 0,
	   values => ["SMAcheckAnswers", "SMAshowSolutions","SMAshowCorrect","SMAshowHints"],
	   type => 'checkboxlist'
	 },
	 
	{	var => 'pg{options}{enablePeriodicRandomization}',
		doc => x('Enable periodic re-randomization of problems'),
		doc2 => x('Enables periodic re-randomization of problems after a given number of attempts. Student would have to click Request New Version to obtain new version of the problem and to continue working on the problem'),
		type => 'boolean'
	},
	{	var => 'pg{options}{periodicRandomizationPeriod}',
		doc => x('The default number of attempts between re-randomization of the problems ( 0 => never)'),
		doc2 => x('The default number of attempts before the problem is re-randomized. ( 0 => never )'),
		type => 'number'
	},
 	],		  
	[x('Permissions'),
		{ var => 'permissionLevels{login}',
		  doc => x('Allowed to login to the course'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{change_password}',
		  doc => x('Allowed to change their password'),
		  doc2 => x('Users at this level and higher are allowed to change their password. Normally guest users are not allowed to change their password.'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{become_student}',
		  doc => x('Allowed to <em>act as</em> another user'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{submit_feedback}',
		  doc => x('Can e-mail instructor'),
		  doc2 => x('Only this permission level and higher get buttons for sending e-mail to the instructor.'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{record_answers_when_acting_as_student}',
		  doc => x('Can submit answers for a student'),
		  doc2 => x('When acting as a student, this permission level and higher can submit answers for that student.'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{report_bugs}',
		  doc => x('Can report bugs'),
		  doc2 => x('Users with at least this permission level get a link in the left panel for reporting bugs to the bug tracking system in Rochester'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{change_email_address}',
		  doc => x('Allowed to change their e-mail address'),
		  doc2 => x('Users at this level and higher are allowed to change their e-mail address. Normally guest users are not allowed to change the e-mail address since it does not make sense to send e-mail to anonymous accounts.'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{view_answers}',
		  doc => x('Allowed to view past answers'),
		  doc2 => x('These users and higher get the "Show Past Answers" button on the problem page.'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{view_unopened_sets}',
		  doc => x('Allowed to view problems in sets which are not open yet'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{show_correct_answers_before_answer_date}',
		  doc => x('Allowed to see the correct answers before the answer date'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{show_solutions_before_answer_date}',
		  doc => x('Allowed to see solutions before the answer date'),
		  type => 'permission'
		},
		{ var => 'permissionLevels{can_show_old_answers}',
		  doc => x('Can show old answers'),
		  doc2 => x('When viewing a problem, WeBWorK usually puts the previously submitted answer in the answer blank.  Below this level, old answers are never shown.  Typically, that is the desired behaviour for guest accounts.'),
		  type => 'permission'
		},
	],
	[x('PG - Problem Display/Answer Checking'),
		{ var => 'pg{displayModes}',
		  doc => x('List of display modes made available to students'),
		  doc2 => x('<p>When viewing a problem, users may choose different methods of rendering formulas via an options box in the left panel. Here, you can adjust what display modes are listed.</p><p>Some display modes require other software to be installed on the server. Be sure to check that all display modes selected here work from your server.</p><p>The display modes are <ul><li> plainText: shows the raw LaTeX srings for formulas.<li> images: produces images using the external programs LaTeX and dvipng.<li> MathJax: a successor to jsMath, uses javascript to place render mathematics.</ul></p></p>You must use at least one display mode. If you select only one, then the options box will not give a choice of modes (since there will only be one active).</p>'),
		  min  => 1,
		  values => ["MathJax", "images", "plainText"],
		  type => 'checkboxlist'
		},

		{ var => 'pg{options}{displayMode}',
		  doc => x('The default display mode'),
		  doc2 => 'Enter one of the allowed display mode types above.  See \'display modes entry\' for descriptions.',
		  min  => 1,
		  values => [qw(MathJax images plainText)],
		  type => 'popuplist'
		},
	        { var  => 'pg{specialPGEnvironmentVars}{MathView}',
                  doc  => 'Use MathView editor for answer entry',
                  doc2 => x('Set to true to display MathView equation editor icon next to each answer box'),
                  type => 'boolean'
                }, 
		{ var => 'pg{options}{showEvaluatedAnswers}',
		  doc => x('Display the evaluated student answer'),
		  doc2 => x('Set to true to display the "Entered" column which automatically shows the evaluated student answer, e.g. 1 if student input is sin(pi/2). If this is set to false, e.g. to save space in the response area, the student can still see their evaluated answer by hovering the mouse pointer over the typeset version of their answer.'),
		  type => 'boolean'
		},		  
 		{ var => 'pg{ansEvalDefaults}{useBaseTenLog}',
		  doc => x('Use log base 10 instead of base <i>e</i>'),
		  doc2 => x('Set to true for log to mean base 10 log and false for log to mean natural logarithm'),
		  type => 'boolean'
		},

		{ var => 'pg{ansEvalDefaults}{useOldAnswerMacros}',
		  doc => x('Use older answer checkers'),
		  doc2 => x('During summer 2005, a newer version of the answer checkers was implemented for answers which are functions and numbers.  The newer checkers allow more functions in student answers, and behave better in certain cases.  Some problems are specifically coded to use new (or old) answer checkers.  However, for the bulk of the problems, you can choose what the default will be here.  <p>Choosing <i>false</i> here means that the newer answer checkers will be used by default, and choosing <i>true</i> means that the old answer checkers will be used by default.'),
		  type => 'boolean'
		  },

		{ var => 'pg{ansEvalDefaults}{numRelPercentTolDefault}',
		  doc => x('Allowed error, as a percentage, for numerical comparisons'),
		  doc2 => "When numerical answers are checked, most test if the student's answer is close enough to the programmed answer be computing the error as a percentage of the correct answer.  This value controls the default for how close the student answer has to be in order to be marked correct.<p>A value such as 0.1 means 0.1 percent error is allowed.",
		  type => 'number'
		},
	],
	[x('E-Mail'),
		{ var => 'mail{feedbackSubjectFormat}',
		  doc => x('Format for the subject line in feedback e-mails'),
		  doc2 => x('When students click the <em>Email Instructor</em> button to send feedback, WeBWorK fills in the subject line.  Here you can set the subject line.  In it, you can have various bits of information filled in with the following escape sequences.<p><ul><li> %c = course ID<li> %u = user ID<li> %s = set ID<li> %p = problem ID<li> %x = section<li> %r = recitation<li> %% = literal percent sign</ul>'),
		  width => 45,
		  type => 'text'
		},
		{ var => 'mail{feedbackVerbosity}',
		  doc => x('E-mail verbosity level'),
		  doc2 => x('The e-mail verbosity level controls how much information is automatically added to feedback e-mails.  Levels are<ol><li value="Simple"> Simple: send only the feedback comment and context link<li value="Standard"> Standard: as in Simple, plus user, set, problem, and PG data<li value="Debug"> Debug: as in Standard, plus the problem environment (debugging data)</ol>'),
		  labels=>{'0' => 'Simple',
			   '1' => 'Standard',
			   '2' => 'Debug'},
		  values => [qw(0 1 2)],
		  type => 'popuplist'

		},
		{ var => 'mail{allowedRecipients}',
		  doc => x('E-mail addresses which can receive e-mail from a pg problem'),
		  doc2 => x('List of e-mail addresses to which e-mail can be sent by a problem. Professors need to be added to this list if questionaires are used, or other WeBWorK problems which send e-mail as part of their answer mechanism.'),
		  type => 'list'
		},
		{ var => 'permissionLevels{receive_feedback}',
		  doc => x('E-mail feedback from students automatically sent to this permission level and higher:'),
		  doc2 => x('Users with this permssion level or greater will automatically be sent feedback from students (generated when they use the "Contact instructor" button on any problem page).  In addition the feedback message will be sent to addresses listed below.  To send ONLY to addresses listed below set permission level to "nobody".'),
		  type => 'permission'
		},
		{ var => 'mail{feedbackRecipients}',
		  doc => x('Additional addresses for receiving feedback e-mail.'),
		  doc2 => x('By default, feeback is sent to all users above who have permission to receive feedback. Feedback is also sent to any addresses specified in this blank. Separate email address entries by commas.'),
		  type => 'list'
		},
		{ var => 'feedback_by_section',
		  doc => x('Feedback by Section.'),
		  doc2 => x('By default, feeback is always sent to all users specified to recieve feedback.  This variable sets the system to only email feedback to users who have the same section as the user initiating the feedback.  I.E.  Feedback will only be sent to section leaders.'),
		  type => 'boolean'
		},

	],
];

