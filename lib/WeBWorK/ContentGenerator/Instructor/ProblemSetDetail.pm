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

package WeBWorK::ContentGenerator::Instructor::ProblemSetDetail;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetDetail - Edit general set and
specific user/set information as well as problem information

=cut

use Exporter qw(import);

use WeBWorK::Utils             qw(cryptPassword x);
use WeBWorK::Utils::Files      qw(surePathToFile readFile);
use WeBWorK::Utils::Instructor qw(assignProblemToAllSetUsers addProblemToSet);
use WeBWorK::Utils::JITAR      qw(seq_to_jitar_id jitar_id_to_seq);
use WeBWorK::Utils::Sets       qw(format_set_name_internal format_set_name_display);
require WeBWorK::PG;

our @EXPORT_OK = qw(FIELD_PROPERTIES);

# These constants determine which fields belong to what type of record.
use constant SET_FIELDS => [
	qw(set_header hardcopy_header open_date reduced_scoring_date due_date answer_date visible description
		enable_reduced_scoring  restricted_release restricted_status restrict_ip relax_restrict_ip
		assignment_type use_grade_auth_proctor attempts_per_version version_time_limit time_limit_cap
		versions_per_interval time_interval problem_randorder problems_per_page
		hide_score:hide_score_by_problem hide_work hide_hint restrict_prob_progression email_instructor)
];
use constant PROBLEM_FIELDS =>
	[qw(source_file value max_attempts showMeAnother showHintsAfter prPeriod att_to_open_children counts_parent_grade)];
use constant USER_PROBLEM_FIELDS => [qw(problem_seed status num_correct num_incorrect)];

# These constants determine what order those fields should be displayed in.
use constant HEADER_ORDER => [qw(set_header hardcopy_header)];
use constant PROBLEM_FIELD_ORDER => [
	qw(problem_seed status value max_attempts showMeAnother showHintsAfter prPeriod attempted last_answer num_correct
		num_incorrect)
];
# For gateway sets, don't allow changing max_attempts on a per problem basis.
use constant GATEWAY_PROBLEM_FIELD_ORDER =>
	[qw(problem_seed status value attempted last_answer num_correct num_incorrect)];
use constant JITAR_PROBLEM_FIELD_ORDER => [
	qw(problem_seed status value max_attempts showMeAnother showHintsAfter prPeriod att_to_open_children
		counts_parent_grade attempted last_answer num_correct num_incorrect)
];

# Exclude the gateway set fields from the set field order, because they are only displayed for sets that are gateways.
# This results in a bit of convoluted logic below, but it saves burdening people who are only using homework assignments
# with all of the gateway parameters.
# FIXME: In the long run, we may want to let hide_score and hide_work be set for non-gateway assignments.  Currently
# they are only used for gateways.
use constant SET_FIELD_ORDER => [
	qw(open_date reduced_scoring_date due_date answer_date visible enable_reduced_scoring restricted_release
		restricted_status restrict_ip relax_restrict_ip hide_hint assignment_type)
];
use constant GATEWAY_SET_FIELD_ORDER => [
	qw(version_time_limit time_limit_cap attempts_per_version time_interval versions_per_interval problem_randorder
		problems_per_page hide_score:hide_score_by_problem hide_work)
];
use constant JITAR_SET_FIELD_ORDER => [qw(restrict_prob_progression email_instructor)];

# This constant is a massive hash of information corresponding to each db field.
# This hash should make it possible to NEVER have explicitly: if (somefield) { blah() }
#
# All but name are optional
#   some_field => {
#     name      => "Some Field",
#     type      => "edit",          # edit, choose, hidden, view - defines how the data is displayed
#     size      => "50",            # size of the edit box (if any)
#     override  => "none",          # none, one, any, all - defines for whom this data can/must be overidden
#     module    => "problem_list",  # WeBWorK module
#     default   => 0                # if a field cannot default to undefined/empty what should it default to
#     labels    => {                # special values can be hashed to display labels
#       1 => x('Yes'),
#       0 => x('No'),
#     },
#     convertby => 60,              # divide incoming database field values by this, and multiply when saving

use constant BLANKPROBLEM => 'newProblem.pg';

# Use the x function to mark strings for localizaton.
use constant FIELD_PROPERTIES => {
	# Set information
	set_header => {
		name     => x('Set Header'),
		type     => 'edit',
		size     => '50',
		override => 'all',
		module   => 'problem_list',
		default  => '',
	},
	hardcopy_header => {
		name     => x('Hardcopy Header'),
		type     => 'edit',
		size     => '50',
		override => 'all',
		module   => 'hardcopy_preselect_set',
		default  => '',
	},
	description => {
		name     => x('Description'),
		type     => 'edit',
		override => 'all',
		default  => '',
	},
	open_date => {
		name      => x('Open Date'),
		type      => 'edit',
		size      => '25',
		override  => 'any',
		help_text => x(
			'This is generally the date when students can begin visiting the set and submitting answers. '
				. 'Prior to this date, if the set is assigned to a user and it is flagged "visible", '
				. 'they can see that it exists and when it will open, but cannot view the problems. '
				. 'If using "course" grade passback to an LMS, only those sets that are past their open date '
				. 'are factored in to the overall course grade that is passed back.  Note that certain '
				. 'permissions can be changed so that the details explained here are no longer true.'
		)
	},
	due_date => {
		name      => x('Close Date'),
		type      => 'edit',
		size      => '25',
		override  => 'any',
		help_text => x(
			'This is generally the date when students can no longer use the "Submit" button to submit an answer and '
				. 'have it assessed for credit.  However students can still visit the set, type or select answers, '
				. 'and use the "Check Answers" button to be assessed without credit.  Note that certain permissions '
				. 'can be changed so that the details explained here are no longer true. This date must come on or '
				. 'after the open date.'
		)
	},
	answer_date => {
		name      => x('Answers Available Date'),
		type      => 'edit',
		size      => '25',
		override  => 'any',
		help_text => x(
			'This is generally the date when students can click a checkbox to see the expected correct answers '
				. 'to problems in the set.  If a problem has a coded solution, this is also when thy can click '
				. 'to see that solution.  Note that certain permissions can be changed so that the details '
				. 'explained here are no longer true.  This date must come on or after the close date.'
		)
	},
	visible => {
		name     => x('Visible to Students'),
		type     => 'choose',
		override => 'all',
		choices  => [qw(0 1)],
		labels   => {
			1 => x('Yes'),
			0 => x('No'),
		},
		help_text =>
			x('Use this to hide the existence of this set from students, even when it is assigned to them.'),
	},
	enable_reduced_scoring => {
		name     => x('Reduced Scoring Enabled'),
		type     => 'choose',
		override => 'any',
		choices  => [qw(0 1)],
		labels   => {
			1 => x('Yes'),
			0 => x('No'),
		},
		help_text => x('See "Reduced Scoring Date".'),
	},
	reduced_scoring_date => {
		name      => x('Reduced Scoring Date'),
		type      => 'edit',
		size      => '25',
		override  => 'any',
		help_text => x(
			'This date should be on or after the open date, and earlier or equal to the close date. '
				. 'Answers submitted between the reduced scoring date and the close date are scaled down '
				. 'by a factor that you can set in the Course Config page.  If reduced scoring is being '
				. 'used, note that students will consider the reduced scoring date to be the "due date", '
				. 'since that is the date when they can no longer earn 100% for problems.'
		)
	},
	restricted_release => {
		name      => x('Restrict Release by Set(s)'),
		type      => 'edit',
		size      => '30',
		override  => 'any',
		help_text => x(
			'This set will be unavailable to students until they have earned the "Score Required for Release" on the '
				. 'sets specified in this field.  The sets should be written as a comma separated list.'
		)
	},
	restricted_status => {
		name     => x('Score Required for Release'),
		type     => 'choose',
		override => 'any',
		choices  => [qw(1 0.9 0.8 0.7 0.6 0.5 0.4 0.3 0.2 0.1)],
		labels   => {
			'0.1' => '10%',
			'0.2' => '20%',
			'0.3' => '30%',
			'0.4' => '40%',
			'0.5' => '50%',
			'0.6' => '60%',
			'0.7' => '70%',
			'0.8' => '80%',
			'0.9' => '90%',
			'1'   => '100%',
		},
		help_text => x('See "Restrict Release by Set(s)".'),
	},
	restrict_ip => {
		name     => x('Restrict Access by Location'),
		type     => 'choose',
		override => 'any',
		choices  => [qw(No RestrictTo DenyFrom)],
		labels   => {
			No         => x('No'),
			RestrictTo => x('Restrict To'),
			DenyFrom   => x('Deny From'),
		},
		default   => 'No',
		help_text => x(
			'You may choose to restrict student access to this set to specified locations.  Alternatively, you may '
				. 'choose to block access from specified locations.  Locations are defined by the WeBWorK '
				. 'administrator by IP address or address range.  The list of defined locations will appear after '
				. 'saving this option with "Restrict To" or "Deny From".'
		)
	},
	relax_restrict_ip => {
		name     => x('Relax Location Restrictions'),
		type     => 'choose',
		override => 'any',
		choices  => [qw(No AfterAnswerDate AfterVersionAnswerDate)],
		labels   => {
			No                     => x('Never'),
			AfterAnswerDate        => x('After Answer Date'),
			AfterVersionAnswerDate => x('After Test Version Answer Date'),
		},
		default   => 'No',
		help_text => x(
			'When location restrictions are applied (see "Restrict Access by Location") you may choose to relax those '
				. 'restrictions after the answer date.  In the case of a test, the set\'s answer date and the date of '
				. 'an individual version may differ, and you can choose which answer date to use.  For a set that is '
				. 'not a test, both options are interpreted as the regular set answer date.'
		)
	},
	assignment_type => {
		name     => x('Assignment Type'),
		type     => 'choose',
		override => 'all',
		choices  => [qw(default gateway proctored_gateway jitar)],
		labels   => {
			default           => x('Homework'),
			gateway           => x('Test'),
			proctored_gateway => x('Proctored Test'),
			jitar             => x('Just in Time Assessment and Review')
		},
		help_text => x(
			'With "Homework", students visit each problem one at a time.  They submit answers for one problem at a '
				. 'time and immediately receive feedback.  With "Test", students will submit all answers for all '
				. 'problems at once.  They may or may not receive feedback right away depending upon other '
				. 'settings.  Also a "Test" can have a time limit, where the student needs to start between the '
				. 'open date and the close date, but once started has only so much time.  Also a "Test" can '
				. 'be configured to allow taking new, re-randomized versions.  A "Proctored Test" is the same as '
				. 'a "Test", but in order to begin, either a classwide password specific to this set is needed, '
				. 'or a higher level user must enter their username and password on the student\'s screen. '
				. 'A "Just in Time Assessment and Review" set is like a "Homework" set, but can be configured '
				. 'to introduce more exercises when a student answers a given exercise incorrectly so many times.'
		)
	},
	version_time_limit => {
		name      => x('Test Time Limit'),
		type      => 'edit',
		size      => '4',
		override  => 'any',
		default   => '0',
		convertby => 60,
		help_text => x(
			'This sets a number of minutes for each version of a test, once it is started.  Use "0" to indicate no '
				. 'time limit.  If there is a time limit, then there will be an indication that this is a timed '
				. 'test on the main "Assignments" page.  Additionally the student will be sent to a confirmation '
				. 'page beefore they can begin.'
		)
	},
	time_limit_cap => {
		name     => x('Cap Test Time at Close Date'),
		type     => 'choose',
		override => 'all',
		choices  => [qw(0 1)],
		labels   => {
			'0' => x('No'),
			'1' => x('Yes')
		},
		help_text => x(
			'A student might start a timed test close to the close date.  This setting allows to either cut them off '
				. 'at the close date or allow them the full time limit.'
		)
	},
	attempts_per_version => {
		name      => x("Graded Submissions per Version"),
		type      => 'edit',
		size      => '3',
		override  => 'any',
		default   => '0',
		help_text => x(
			'A test may be configured to allow students one or more versions.  For each version, this is the number of '
				. 'times you will allow them to click to have that version graded.  Depending on other settings, '
				. 'they may or may not be able to see scores and feedback following each grading. '
				. 'Use "0" to indicate there is no cap on the number of graded submissions.'
		)
	},
	time_interval => {
		name      => x('Time Interval for New Versions'),
		type      => 'edit',
		size      => '5',
		override  => 'any',
		default   => '0',
		convertby => 60,
		help_text => x(
			'You may set a time interval in minutes.  Within this time interval, students may start new randomized '
				. 'versions of the test.  However they may only start as many new versions as you set for "Versions '
				. 'per Interval".  When the time interval ends, the cap is reset.  This feature is intended to allow '
				. 'students an immediate retake, but require them to take a break (and perhaps study more) after too '
				. 'many low scoring attempts in close succession.  Use "0" to indicate an infinite time interval, '
				. 'which is what you want for an absolute cap on the number of new versions overall.'
		)
	},
	versions_per_interval => {
		name      => x('Versions per Interval'),
		type      => 'edit',
		size      => '3',
		override  => 'any',
		default   => '0',
		format    => '[0-9]+',                                     # an integer, possibly zero
		help_text => x('See "Time Interval for New Versions".'),
	},
	problem_randorder => {
		name     => x('Order Problems Randomly'),
		type     => 'choose',
		choices  => [qw(0 1)],
		override => 'any',
		labels   => {
			0 => x('No'),
			1 => x('Yes')
		},
		help_text => x(
			'Order problems randomly or not.  If you will be manually reviewing student answers, you might not want to '
				. 'order problems randomly to facilitate assembly line grading.'
		)
	},
	problems_per_page => {
		name      => x('Problems per Page'),
		type      => 'edit',
		size      => '3',
		override  => 'any',
		default   => '1',
		help_text => x(
			'A test is broken up into pages with this many problems on each page.  Students can move from page to page '
				. 'without clicking to grade the test, and their temporary answers will be saved.  Use "0" to indicate '
				. '"all problems on one page".  For tests with many problems, either extreme (1 per page or "all on '
				. 'one page") has drawbacks.  With 1 per page, the student has many pages and may be frustrated trying '
				. 'to go back and find a particular problem.  With "all on one page", the student may spend a lot of '
				. 'time on that one page without clicking anything that lets WeBWorK know they are still active, and '
				. 'their session might expire for inactivity before they get around to clicking the grade button. '
				. 'This situation can lead to their typed answers being lost and unrecoverable.  Additionally, having '
				. 'many problems load at the same time on one page can put a strain on the server.  This is especially '
				. 'worth considering if the test has many dynamically generated images, which can slow things down '
				. 'significantly.'
		)
	},
	'hide_score:hide_score_by_problem' => {
		name     => x('Show Scores on Finished Versions'),
		type     => 'choose',
		choices  => [qw(N:N Y:Y BeforeAnswerDate:N N:Y BeforeAnswerDate:Y)],
		override => 'any',
		labels   => {
			'N:N'                => x('Yes'),
			'Y:Y'                => x('No'),
			'BeforeAnswerDate:N' => x('Only after set answer date'),
			'N:Y'                => x('Totals only (not problem scores)'),
			'BeforeAnswerDate:Y' => x('Totals only, only after answer date')
		},
		default   => 'N:N',
		help_text => x(
			'After a test version either has no more allowed graded submissions or has its time limit expired, you may '
				. 'configure whether or not to allow students to see their scores on that version.'
		)
	},
	hide_work => {
		name     => x('Show Problems on Finished Versions'),
		type     => 'choose',
		choices  => [qw(N Y BeforeAnswerDate)],
		override => 'any',
		labels   => {
			'N'                => x('Yes'),
			'Y'                => x('No'),
			'BeforeAnswerDate' => x('Only after set answer date')
		},
		default   => 'N',
		help_text => x(
			'After a test version either has no more allowed graded submissions or has its time limit expired, you may '
				. 'configure whether or not to allow students to see the questions and the responses they gave.'
		)
	},
	use_grade_auth_proctor => {
		name     => x('Proctor Authorization Type'),
		type     => 'choose',
		override => 'any',
		choices  => [qw(Yes No)],
		labels   => {
			Yes => x('Both Start and Grade'),
			No  => x('Only Start')
		},
		default   => 'Yes',
		help_text => x(
			'Proctored tests always require authorization to start the test. "Both Start and Grade" will require '
				. 'either login proctor authorization or a password specific to this set to start the test, '
				. 'and grade proctor authorization to grade the test. "Only Start" requires either grade proctor '
				. 'authorization or a password specific to this set to start and no authorization to grade.'
		),
	},
	restrict_prob_progression => {
		name     => x('Restrict Problem Progression'),
		type     => 'choose',
		choices  => [qw(0 1)],
		override => 'all',
		default  => '0',
		labels   => {
			'1' => x('Yes'),
			'0' => x('No'),
		},
		help_text => x(
			'If this is enabled then students will be unable to attempt a problem until they have '
				. 'completed all of the previous problems and their child problems if necessary.'
		),
	},
	email_instructor => {
		name     => x('Email Instructor On Failed Attempt'),
		type     => 'choose',
		choices  => [qw(0 1)],
		override => 'any',
		default  => '0',
		labels   => {
			'1' => x('Yes'),
			'0' => x('No')
		},
		help_text => x(
			'If this is enabled then instructors with the ability to receive feedback emails will be '
				. 'notified whenever a student runs out of attempts on a problem and its children '
				. 'without receiving an adjusted status of 100%.'
		),
	},

	# In addition to the set fields above, there are a number of things
	# that are set but aren"t in this table:
	#    any set proctor information (which is in the user tables), and
	#    any set location restriction information (which is in the
	#    location tables)

	# Problem information
	source_file => {
		name     => x('Source File'),
		type     => 'edit',
		size     => 50,
		override => 'any',
		default  => '',
	},
	value => {
		name      => x('Weight'),
		type      => 'edit',
		size      => 6,
		override  => 'any',
		default   => '1',
		help_text => x(
			'This is a relative weight to be attached to the problem, either in the context of scoring the set, '
				. 'or in the context of calculating a score for a collection of sets.'
		)
	},
	max_attempts => {
		name     => x('Max Attempts'),
		type     => 'edit',
		size     => 6,
		override => 'any',
		default  => '-1',
		labels   => {
			'-1' => x('Unlimited'),
		},
		help_text => x(
			'You may cap the number of attempts a student can use for the problem. Use -1 to indicate unlimited attempts.'
		)
	},
	showMeAnother => {
		name     => x('Show Me Another'),
		type     => 'edit',
		size     => '6',
		override => 'any',
		default  => '-1',
		labels   => {
			'-1' => x('Never'),
			'-2' => x('Course Default'),
		},
		help_text => x(
			'When a student has more attempts than is specified here they will be able to view another '
				. 'version of this problem.  If set to -1 the feature is disabled and if set to -2 '
				. 'the course default is used.'
		)
	},
	showHintsAfter => {
		name     => x('Show Hints After'),
		type     => 'edit',
		size     => '6',
		override => 'any',
		default  => '-2',
		labels   => {
			'-2' => x('Course Default'),
			'-1' => x('Never'),
		},
		help_text => x(
			'This specifies the number of attempts before hints are shown to students. '
				. 'The value of -2 uses the default from course configuration. '
				. 'The value of -1 disables hints. '
				. 'Note that this will only have an effect if the problem has a hint.'
		),
	},
	prPeriod => {
		name     => x('Rerandomize After'),
		type     => 'edit',
		size     => '6',
		override => 'any',
		default  => '-1',
		labels   => {
			'-1' => x('Course Default'),
			'0'  => x('Never'),
		},
		help_text => x(
			'This specifies the rerandomization period: the number of attempts before a new version of '
				. 'the problem is generated by changing the Seed value. The value of -1 uses the '
				. 'default from course configuration. The value of 0 disables rerandomization.'
		),
	},
	problem_seed => {
		name      => x('Seed'),
		type      => 'edit',
		size      => 6,
		override  => 'one',
		help_text => x(
			'This number is used to control how the random elements of the problem will be generated. '
				. 'Change this number to rerandomize a student\'s version.'
		)
	},
	status => {
		name      => x('Status'),
		type      => 'edit',
		size      => 6,
		override  => 'one',
		default   => '0',
		help_text => x(
			'This is a number between 0 and 1 indicating the student\'s score for the problem.  Change this '
				. 'to 1 to manually award full credit on this problem.'
		)
	},
	attempted => {
		name     => x('Attempted'),
		type     => 'hidden',
		override => 'none',
		choices  => [qw(0 1)],
		labels   => {
			1 => x('Yes'),
			0 => x('No'),
		},
		default => '0',
	},
	last_answer => {
		name     => x('Last Answer'),
		type     => 'hidden',
		override => 'none',
	},
	num_correct => {
		name     => x('Correct'),
		type     => 'hidden',
		override => 'none',
		default  => '0',
	},
	num_incorrect => {
		name     => x('Incorrect'),
		type     => 'hidden',
		override => 'none',
		default  => '0',
	},
	hide_hint => {
		name     => x('Hide Hints from Students'),
		type     => 'choose',
		override => 'all',
		choices  => [qw(0 1)],
		labels   => {
			1 => x('Yes'),
			0 => x('No'),
		},
		help_text => x(
			'Problem files may have hints included in their code.  Use this option to suppress showing students these '
				. 'hints. Note that even if hints are not suppressed, there is a threshold number of attempts '
				. 'that a student must make before they have the option to view a hint.'
		)
	},
	att_to_open_children => {
		name     => x('Attempt Threshold for Children'),
		type     => 'edit',
		size     => 6,
		override => 'any',
		default  => '0',
		labels   => {
			'-1' => x('max'),
		},
		help_text => x(
			'The child problems for this problem will become visible to the student when they either have more '
				. 'incorrect attempts than is specified here, or when they run out of attempts, whichever comes '
				. 'first.  Use -1 to indicate that child problems should only be available after a student '
				. 'runs out of attempts.'
		),
	},
	counts_parent_grade => {
		name     => x('Counts for Parent'),
		type     => 'choose',
		choices  => [qw(0 1)],
		override => 'any',
		default  => '0',
		labels   => {
			'1' => x('Yes'),
			'0' => x('No'),
		},
		help_text => x(
			'If this flag is set then this problem will count toward the grade of its parent problem.  In '
				. 'general the adjusted status on a problem is the larger of the problem\'s status and the weighted '
				. 'average of the status of its child problems which have this flag enabled.'
		),
	},
};

use constant FIELD_PROPERTIES_GWQUIZ => {
	max_attempts => {
		type     => 'hidden',
		override => 'any',
	}
};

# Create a table of fields for the given parameters, one row for each db field.
# If only the setID is included, it creates a table of set information.
# If the problemID is included, it creates a table of problem information.
sub fieldTable ($c, $userID, $setID, $problemID, $globalRecord, $userRecord = undef, $setType = undef) {
	my $ce          = $c->ce;
	my @editForUser = $c->param('editForUser');
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;
	my $isGWset     = defined $setType && $setType =~ /gateway/;
	my $isJitarSet  = defined $setType && $setType =~ /jitar/;

	# Needed for gateway/jitar output
	my $extraFields = '';

	# Are we editing a set version?
	my $setVersion = defined($userRecord) && $userRecord->can('version_id') ? 1 : 0;

	# Needed for ip restrictions
	my $ipFields     = '';
	my $numLocations = 0;

	# Needed for set-level proctor
	my $procFields = '';

	my @fieldOrder;
	if (defined $problemID) {
		if ($isJitarSet) {
			@fieldOrder = @{ JITAR_PROBLEM_FIELD_ORDER() };
		} elsif ($isGWset) {
			@fieldOrder = @{ GATEWAY_PROBLEM_FIELD_ORDER() };
		} else {
			@fieldOrder = @{ PROBLEM_FIELD_ORDER() };
		}
	} else {
		@fieldOrder = @{ SET_FIELD_ORDER() };

		($extraFields, $ipFields, $numLocations, $procFields) =
			$c->extraSetFields($userID, $setID, $globalRecord, $userRecord, $forUsers);
	}

	my $rows = $c->c;

	if ($forUsers) {
		push(
			@$rows,
			$c->tag(
				'tr',
				$problemID ? () : (class => 'table-primary'),
				$c->c(
					$c->tag(
						'th',
						class   => 'p-2',
						scope   => 'colgroup',
						colspan => 2,
						$problemID ? '' : $c->maketext('General Parameters')
					),
					$c->tag('th', class => 'p-2', scope => 'col', $c->maketext('User Overrides')),
					$c->tag('th', class => 'p-2', scope => 'col', $c->maketext('Set Values'))
				)->join('')
			)
		);
	} elsif (!$problemID) {
		push(
			@$rows,
			$c->tag(
				'tr',
				class => 'table-primary',
				$c->tag(
					'th',
					class   => 'p-2',
					scope   => 'colgroup',
					colspan => 3,
					$c->maketext('General Parameters')
				)
			)
		);
	}

	for my $field (@fieldOrder) {
		my %properties;

		if ($isGWset && defined(FIELD_PROPERTIES_GWQUIZ->{$field})) {
			%properties = %{ FIELD_PROPERTIES_GWQUIZ->{$field} };
		} else {
			%properties = %{ FIELD_PROPERTIES()->{$field} };
		}

		# Don't show fields if that option isn't enabled.
		if (!$ce->{options}{enableConditionalRelease}
			&& ($field eq 'restricted_release' || $field eq 'restricted_status'))
		{
			$properties{'type'} = 'hidden';
		}

		if (!$ce->{pg}{ansEvalDefaults}{enableReducedScoring}
			&& ($field eq 'reduced_scoring_date' || $field eq 'enable_reduced_scoring'))
		{
			$properties{'type'} = 'hidden';
		} elsif ($ce->{pg}{ansEvalDefaults}{enableReducedScoring}
			&& $field eq 'reduced_scoring_date'
			&& !$globalRecord->reduced_scoring_date)
		{
			$globalRecord->reduced_scoring_date(
				$globalRecord->due_date - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
		}

		# We don't show the ip restriction option if there are
		# no defined locations, nor the relax_restrict_ip option
		# if we're not restricting ip access.
		next if ($field eq 'restrict_ip' && (!$numLocations || $setVersion));
		next
			if (
				$field eq 'relax_restrict_ip'
				&& (!$numLocations
					|| $setVersion
					|| ($forUsers  && $userRecord->restrict_ip eq 'No')
					|| (!$forUsers && ($globalRecord->restrict_ip eq '' || $globalRecord->restrict_ip eq 'No')))
			);

		# Skip the problem seed if we are not editing for one user, or if we are editing a gateway set for users,
		# but aren't editing a set version.
		next if ($field eq 'problem_seed' && (!$forOneUser || ($isGWset && $forUsers && !$setVersion)));

		# Skip the status if we are not editing for one user.
		next if ($field eq 'status' && !$forOneUser);

		# Skip the Show Me Another value if SMA is not enabled.
		next if ($field eq 'showMeAnother' && !$ce->{pg}{options}{enableShowMeAnother});

		# Skip the periodic re-randomization field if it is not enabled.
		next if ($field eq 'prPeriod' && !$ce->{pg}{options}{enablePeriodicRandomization});

		unless ($properties{type} eq 'hidden') {
			my @row = $c->fieldHTML($userID, $setID, $problemID, $globalRecord, $userRecord, $field);
			push(@$rows, $c->tag('tr', $c->c(map { $c->tag('td', $_) } @row)->join(''))) if @row > 1;
		}

		# Finally, put in extra fields that are exceptions to the usual display mechanism.
		push(@$rows, $ipFields) if $field eq 'restrict_ip' && $ipFields;

		push(@$rows, $extraFields, $procFields) if $field eq 'assignment_type';
	}

	if (defined $problemID && $forOneUser) {
		my $problemRecord = $userRecord;
		push(
			@$rows,
			$c->include(
				'ContentGenerator/Instructor/ProblemSetDetail/attempts_row',
				problemID     => $problemID,
				problemRecord => $problemRecord
			)
		);
	}

	return $c->tag(
		'table',
		class => 'table table-sm table-borderless align-middle font-sm mb-0',
		$rows->join('')
	);
}

# Returns a list of information and HTML widgets for viewing and editing the specified db fields.
# If only the setID is included, it creates a list of set information.
# If the problemID is included, it creates a list of problem information.
sub fieldHTML ($c, $userID, $setID, $problemID, $globalRecord, $userRecord, $field) {
	my $db          = $c->db;
	my @editForUser = $c->param('editForUser');
	my $forUsers    = @editForUser;
	my $forOneUser  = $forUsers == 1;

	return $c->maketext('No data exists for set [_1] and problem [_2]', $setID, $problemID) unless $globalRecord;
	return $c->maketext('No user specific data exists for user [_1]', $userID)
		if $forOneUser && $globalRecord && !$userRecord;

	my %properties = %{ FIELD_PROPERTIES()->{$field} };

	return '' if $properties{type} eq 'hidden';
	return '' if $properties{override} eq 'one'  && !$forOneUser;
	return '' if $properties{override} eq 'none' && !$forOneUser;
	return '' if $properties{override} eq 'all'  && $forUsers;

	my $edit   = $properties{type} eq 'edit'   && $properties{override} ne 'none';
	my $choose = $properties{type} eq 'choose' && $properties{override} ne 'none';

	my ($globalValue, $userValue, $blankField) = (undef, undef, '');
	if ($field =~ /:/) {
		# This allows one "select" to set multiple database fields.
		# (Used only by hide_score:hide_score_by_problem, i.e., "Show Scores on Finished Versions".)
		# This is an example of a hack that shouldn't be done. This option should have been implemented with a single
		# database field to begin with.  Too late to change that for backward compatibility.
		my @gVals;
		my @uVals;
		my @bVals;
		for my $f (split(/:/, $field)) {
			push(@gVals, $globalRecord->can($f)              ? $globalRecord->$f : undef);
			push(@uVals, $userRecord && $userRecord->can($f) ? $userRecord->$f   : undef);
			push(@bVals, '');
		}
		# I don't like this, but combining multiple values is a bit messy
		$globalValue = (grep {defined} @gVals) ? join(':', map { $_ // '' } @gVals) : undef;
		$userValue   = (grep {defined} @uVals) ? join(':', map { $_ // '' } @uVals) : undef;
		$blankField  = join(':', @bVals);
	} else {
		$globalValue = $globalRecord->can($field)              ? $globalRecord->$field : undef;
		$userValue   = $userRecord && $userRecord->can($field) ? $userRecord->$field   : undef;
	}

	$globalValue //= '';
	$userValue   //= $blankField;

	if ($properties{convertby}) {
		$globalValue = $globalValue / $properties{convertby} if $globalValue;
		$userValue   = $userValue / $properties{convertby}   if $userValue;
	}

	# Check to see if the given value can be overridden.
	my $canOverride = grep { $_ eq $field } (@{ PROBLEM_FIELDS() }, @{ SET_FIELDS() });

	# Determine if this is a set record or problem record.
	my ($recordType, $recordID) = defined $problemID ? ('problem', $problemID) : ('set', $setID);

	my %labels = (map { $_ => $c->maketext($properties{labels}{$_}) } keys %{ $properties{labels} });

	# This contains either a text input or a select for changing a given database field.
	my $input = '';

	if ($edit) {
		if ($field =~ /_date/) {
			$input = $c->tag(
				'div',
				class => 'input-group input-group-sm flatpickr',
				$c->c(
					$c->text_field(
						"$recordType.$recordID.$field",
						$forUsers ? $userValue : $globalValue,
						id    => "$recordType.$recordID.${field}_id",
						class => 'form-control form-control-sm'
							. ($field eq 'open_date' ? ' datepicker-group' : ''),
						placeholder => (
							$forUsers && $canOverride ? $c->maketext('Set Default') : $c->maketext('None Specified')
						),
						data => {
							input      => undef,
							done_text  => $c->maketext('Done'),
							today_text => $c->maketext('Today'),
							now_text   => $c->maketext('Now'),
							locale     => $c->ce->{language},
							timezone   => $c->ce->{siteDefaults}{timezone}
						}
					),
					$c->tag(
						'a',
						class        => 'btn btn-secondary btn-sm',
						data         => { toggle => undef },
						role         => 'button',
						tabindex     => 0,
						'aria-label' => $c->maketext('Pick date and time'),
						$c->tag('i', class => 'fas fa-calendar-alt', 'aria-hidden' => 'true', '')
					)
				)->join('')
			);
		} else {
			my $value = $forUsers ? ($labels{$userValue} || $userValue) : ($labels{$globalValue} || $globalValue);
			$value = format_set_name_display($value =~ s/\s*,\s*/,/gr) if $field eq 'restricted_release';

			my @field_args = (
				"$recordType.$recordID.$field", $value,
				id    => "$recordType.$recordID.${field}_id",
				class => 'form-control form-control-sm',
				$field eq 'restricted_release' || $field eq 'source_file' ? (dir => 'ltr') : ()
			);
			if ($field eq 'problem_seed') {
				# Insert a randomization button
				$input = $c->tag(
					'div',
					class => 'input-group input-group-sm',
					style => 'min-width: 7rem',
					$c->c(
						$c->number_field(@field_args, min => 0),
						$c->tag(
							'button',
							type  => 'button',
							class => 'randomize-seed-btn btn btn-sm btn-secondary',
							title => 'randomize',
							data  => {
								seed_input   => "$recordType.$recordID.problem_seed_id",
								status_input => "$recordType.$recordID.status_id"
							},
							$c->tag('i', class => 'fa-solid fa-shuffle')
						)
					)->join('')
				);
			} else {
				$input = $c->text_field(@field_args,
					$forUsers && $canOverride ? (placeholder => $c->maketext('Set Default')) : ());
			}
		}
	} elsif ($choose) {
		my $value = $forUsers ? $userValue : $globalValue;

		$input = $c->select_field(
			"$recordType.$recordID.$field",
			[
				$forUsers && $userRecord ? [ $c->maketext('Set Default') => '' ] : (),
				map { [ $labels{$_} => $_, $_ eq $value ? (selected => undef) : () ] } @{ $properties{choices} }
			],
			id    => "$recordType.$recordID.${field}_id",
			class => 'form-select form-select-sm'
		);
	}

	my $globalDisplayValue =
		$labels{$globalValue}            ? $labels{$globalValue}
		: $field =~ /_date/              ? $c->formatDateTime($globalValue, 'datetime_format_short')
		: $field eq 'restricted_release' ? format_set_name_display($globalValue)
		:                                  $globalValue;

	my @return;

	push @return,
		$c->label_for(
			"$recordType.$recordID.${field}_id",
			$c->maketext($properties{name}),
			class => 'form-label mb-0',
			$forUsers ? (id => "$recordType.$recordID.$field.label") : ()
		);

	push @return,
		$properties{help_text}
		? $c->tag(
			'a',
			class    => 'help-popup',
			role     => 'button',
			tabindex => 0,
			data     => {
				bs_content   => $c->maketext($properties{help_text}),
				bs_placement => 'top',
				bs_toggle    => 'popover'
			},
			$c->c(
				$c->tag('i',    class => 'icon fas fa-question-circle', 'aria-hidden' => 'true'),
				$c->tag('span', class => 'visually-hidden',             $c->maketext('Help'))
		)->join('')
		)
		: '';

	push @return, $input;

	push @return,
		(
			$globalDisplayValue ne ''
			? $c->text_field(
				"$recordType.$recordID.$field.class_value",
				$globalDisplayValue,
				readonly          => undef,
				size              => $properties{size} || 5,
				class             => 'form-control-plaintext form-control-sm',
				'aria-labelledby' => "$recordType.$recordID.$field.label",
				$field =~ /date/ || $field eq 'restricted_release' || $field eq 'source_file' ? (dir => 'ltr') : (),
				data => { class_value => $globalValue }
			)
			: ''
		) if $forUsers;

	return @return;
}

# Return weird fields that are non-native or which are displayed for only some sets.
sub extraSetFields ($c, $userID, $setID, $globalRecord, $userRecord, $forUsers) {
	my $db = $c->{db};

	my $extraFields = '';
	my $num_columns = 0;

	if ($globalRecord->assignment_type() =~ /gateway/) {
		# If this is a gateway set, set up a table of gateway fields.
		my @gwFields;

		for my $gwfield (@{ GATEWAY_SET_FIELD_ORDER() }) {
			# Don't show template gateway fields when editing set versions.
			next
				if (($gwfield eq "time_interval" || $gwfield eq "versions_per_interval")
					&& ($forUsers && $userRecord->can('version_id')));

			my @fieldData = $c->fieldHTML($userID, $setID, undef, $globalRecord, $userRecord, $gwfield);
			if (@fieldData && defined($fieldData[0]) && $fieldData[0] ne '') {
				$num_columns = @fieldData if @fieldData > $num_columns;
				push(@gwFields, $c->tag('tr', $c->c(map { $c->tag('td', $_) } @fieldData)->join('')));
			}
		}

		$extraFields = $c->c(
			$num_columns
			? $c->tag(
				'tr',
				class => 'table-primary',
				$c->tag(
					'th',
					class   => 'p-2',
					scope   => 'colgroup',
					colspan => $num_columns,
					$c->maketext('Test Parameters')
				)
				)
			: '',
			@gwFields
		)->join('');
	} elsif ($globalRecord->assignment_type eq 'jitar') {
		# If this is a jitar set, set up a table of jitar fields.
		my $jthdr = '';
		my @jtFields;
		for my $jtfield (@{ JITAR_SET_FIELD_ORDER() }) {
			my @fieldData = $c->fieldHTML($userID, $setID, undef, $globalRecord, $userRecord, $jtfield);
			if (@fieldData && defined($fieldData[0]) && $fieldData[0] ne '') {
				$num_columns = @fieldData if (@fieldData > $num_columns);
				push(@jtFields, $c->tag('tr', $c->c(map { $c->tag('td', $_) } @fieldData)->join('')));
			}
		}
		$extraFields = $c->c(
			$num_columns
			? $c->tag(
				'tr',
				class => 'table-primary',
				$c->tag(
					'th',
					class   => 'p-2',
					scope   => 'colgroup',
					colspan => $num_columns,
					$c->maketext('Just-In-Time Parameters')
				)
				)
			: '',
			@jtFields
		)->join('');
	}

	my $procFields = '';

	# If this is a proctored test, then add a dropdown menu to configure using a grade proctor
	# and a proctored set password input.
	if ($globalRecord->assignment_type eq 'proctored_gateway') {
		$procFields = $c->c(
			$c->tag(
				'tr',
				class => 'table-primary',
				$c->tag(
					'th',
					class   => 'p-2',
					scope   => 'colgroup',
					colspan => $num_columns,
					$c->maketext('Proctoring Parameters')
				)
			),
			# Dropdown menu to configure using a grade proctor.
			$c->tag(
				'tr',
				$c->c(
					map { $c->tag('td', $_) }
						$c->fieldHTML($userID, $setID, undef, $globalRecord, $userRecord, 'use_grade_auth_proctor')
				)->join('')
			),
			$forUsers ? '' : $c->include(
				'ContentGenerator/Instructor/ProblemSetDetail/restricted_login_proctor_password_row',
				globalRecord => $globalRecord
			)
		)->join('');
	}

	# Figure out what ip selector fields to include.
	my @locations    = sort { $a cmp $b } $db->listLocations;
	my $numLocations = @locations;

	my $ipFields = '';

	if (
		(!defined $userRecord || (defined $userRecord && !$userRecord->can('version_id')))
		&& ((!$forUsers && $globalRecord->restrict_ip && $globalRecord->restrict_ip ne 'No')
			|| ($forUsers && $userRecord->restrict_ip ne 'No'))
		)
	{
		my $ipOverride      = 0;
		my @globalLocations = $db->listGlobalSetLocations($setID);

		# Which ip locations should be selected?
		my %defaultLocations;
		if (!$forUsers || !$db->countUserSetLocations($userID, $setID)) {
			%defaultLocations = map { $_ => 1 } @globalLocations;
		} else {
			%defaultLocations = map { $_ => 1 } $db->listUserSetLocations($userID, $setID);
			$ipOverride       = 1;
		}

		$ipFields = $c->include(
			'ContentGenerator/Instructor/ProblemSetDetail/ip_locations_row',
			forUsers         => $forUsers,
			ipOverride       => $ipOverride,
			locations        => \@locations,
			defaultLocations => \%defaultLocations,
			globalLocations  => \@globalLocations
		);
	}
	return ($extraFields, $ipFields, $numLocations, $procFields);
}

# This is a recursive function which displays the tree structure of jitar sets.
# Each child is displayed as a nested ordered list.
sub print_nested_list ($c, $nestedHash) {
	my $output = $c->c;

	# This hash contains information about the problem at this node.  Output the problem row and delete the "id" and
	# "row" keys.  Any remaining keys are references to child nodes which are shown in a sub list via the recursion.
	# Note that the only reason the "id" and "row" keys need to be deleted is because those keys are not numeric for the
	# key sort.
	if (defined $nestedHash->{row}) {
		my $id = delete $nestedHash->{id};
		push(
			@$output,
			$c->tag(
				'li',
				class => 'psd_list_item',
				id    => "psd_list_item_$id",
				$c->c(
					delete $nestedHash->{row},
					$c->tag(
						'ol',
						class => 'sortable-branch collapse',
						id    => "psd_sublist_$id",
						sub {
							my $sub_output = $c->c;
							my @keys       = keys %$nestedHash;
							if (@keys) {
								for (sort { $a <=> $b } @keys) {
									push(@$sub_output, $c->print_nested_list($nestedHash->{$_}));
								}
							}
							return $sub_output->join('');
						}
					)
				)->join('')
			)
		);
	}

	return $output->join('');
}

# Handles rearrangement necessary after changes to problem ordering.
sub handle_problem_numbers ($c, $newProblemNumbers, $db, $setID) {
	# Check to see that everything has a number and if anything was renumbered.
	my $force = 0;
	for my $j (keys %$newProblemNumbers) {
		return ""  if !defined $newProblemNumbers->{$j};
		$force = 1 if $newProblemNumbers->{$j} != $j;
	}

	# we dont do anything unless a problem has been reordered or we were asked to
	return "" unless $force;

	# get problems and store them in a hash.
	# We do this all at once because its not always clear
	# what is overwriting what and when.
	# We try to keep things sane by only getting and storing things
	# which have actually been reordered
	my %problemHash;
	my @setUsers = $db->listSetUsers($setID);
	my %userProblemHash;

	for my $j (keys %$newProblemNumbers) {
		next if $newProblemNumbers->{$j} == $j;

		$problemHash{$j} = $db->getGlobalProblem($setID, $j);
		die $c->maketext("global [_1] for set [_2] not found.", $j, $setID) unless $problemHash{$j};
		foreach my $user (@setUsers) {
			$userProblemHash{$user}{$j} = $db->getUserProblem($user, $setID, $j);
			warn $c->maketext(
				"UserProblem missing for user=[_1] set=[_2] problem=[_3]. This may indicate database corruption.",
				$user, $setID, $j)
				. "\n"
				unless $userProblemHash{$user}{$j};
		}
	}

	# now go through and move problems around
	# because of the way the reordering works with the draggable
	# js handler we cant have any conflicts or holes
	for my $j (keys %$newProblemNumbers) {
		next if ($newProblemNumbers->{$j} == $j);

		$problemHash{$j}->problem_id($newProblemNumbers->{$j});
		if ($db->existsGlobalProblem($setID, $newProblemNumbers->{$j})) {
			$db->putGlobalProblem($problemHash{$j});
		} else {
			$db->addGlobalProblem($problemHash{$j});
		}

		# now deal with the user sets

		foreach my $user (@setUsers) {

			$userProblemHash{$user}{$j}->problem_id($newProblemNumbers->{$j});
			if ($db->existsUserProblem($user, $setID, $newProblemNumbers->{$j})) {
				$db->putUserProblem($userProblemHash{$user}{$j});
			} else {
				$db->addUserProblem($userProblemHash{$user}{$j});
			}

		}

		# now we need to delete "orphan" problems that were not overwritten by something else
		my $delete = 1;
		foreach my $k (keys %$newProblemNumbers) {
			$delete = 0 if ($j == $newProblemNumbers->{$k});
		}

		if ($delete) {
			$db->deleteGlobalProblem($setID, $j);
		}

	}

	# return a string form of the old problem IDs in the new order (not used by caller, incidentally)
	return join(', ', values %$newProblemNumbers);
}

# Primarily saves any changes into the correct set or problem records (global vs user).
# Also deals with deleting or rearranging problems.
sub initialize ($c) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;
	my $user  = $c->param('user');
	my $setID = $c->stash('setID');

	# Make sure these are defined for the templates.
	$c->stash->{fullSetID}           = $setID;
	$c->stash->{headers}             = HEADER_ORDER();
	$c->stash->{field_properties}    = FIELD_PROPERTIES();
	$c->stash->{display_modes}       = WeBWorK::PG::DISPLAY_MODES();
	$c->stash->{unassignedUsers}     = [];
	$c->stash->{problemIDList}       = [];
	$c->stash->{globalProblems}      = {};
	$c->stash->{userProblems}        = {};
	$c->stash->{userProblemVersions} = {};

	# A set may be provided with a version number (as in setID,v#).
	# If so obtain the template set id and version number.
	my $editingSetVersion = 0;
	if ($setID =~ /,v(\d+)$/) {
		$editingSetVersion = $1;
		$setID =~ s/,v(\d+)$//;
	}

	$c->stash->{setID}             = $setID;
	$c->stash->{editingSetVersion} = $editingSetVersion;

	my $setRecord = $db->getGlobalSet($setID);
	$c->stash->{setRecord} = $setRecord;
	return unless $setRecord;

	return unless ($authz->hasPermissions($user, 'access_instructor_tools'));
	return unless ($authz->hasPermissions($user, 'modify_problem_sets'));

	my @editForUser = $c->param('editForUser');

	my $forUsers = scalar(@editForUser);
	$c->stash->{forUsers} = $forUsers;
	my $forOneUser = $forUsers == 1;
	$c->stash->{forOneUser} = $forOneUser;

	# If editing a versioned set, it only makes sense edit it for one user.
	return if ($editingSetVersion && !$forOneUser);

	my %properties = %{ FIELD_PROPERTIES() };

	# Invert the labels hashes.
	my %undoLabels;
	for my $key (keys %properties) {
		%{ $undoLabels{$key} } =
			map { $c->maketext($properties{$key}{labels}{$_}) => $_ } keys %{ $properties{$key}{labels} };
	}

	my $error = 0;
	if ($c->param('submit_changes')) {
		my @names = ('open_date', 'due_date', 'answer_date', 'reduced_scoring_date');

		my %dates;
		$dates{$_} =
			($c->param("set.$setID.$_") && $c->param("set.$setID.$_") ne '')
			? $c->param("set.$setID.$_")
			: (!$forUsers || $editingSetVersion ? 0 : $setRecord->$_)
			for @names;

		my ($open_date, $due_date, $answer_date, $reduced_scoring_date) = map { $dates{$_} } @names;

		unless ($open_date && $due_date && $answer_date) {
			$c->addbadmessage($c->maketext(
				'There are errors in the dates. Open Date: [_1] , Close Date: [_2], Answer Date: [_3]',
				map { $_ ? $c->formatDateTime($_, 'datetime_format_short') : $c->maketext('required') }
					($open_date, $due_date, $answer_date)
			));
			$error = 1;
		} else {
			if (
				$ce->{pg}{ansEvalDefaults}{enableReducedScoring}
				&& (
					defined($c->param("set.$setID.enable_reduced_scoring"))
					? $c->param("set.$setID.enable_reduced_scoring")
					: $setRecord->enable_reduced_scoring)
				&& $reduced_scoring_date
				&& ($reduced_scoring_date > $due_date || $reduced_scoring_date < $open_date)
				)
			{
				$c->addbadmessage(
					$c->maketext('The reduced scoring date should be between the open date and close date.'));
				$error = 1;
			}

			if ($due_date < $open_date) {
				$c->addbadmessage($c->maketext('The close date must be on or after the open date.'));
				$error = 1;
			}

			if ($answer_date < $due_date) {
				$c->addbadmessage($c->maketext('Answers cannot be made available until on or after the close date.'));
				$error = 1;
			}
		}
	}

	$c->addbadmessage($c->maketext('No changes were saved!')) if $error;

	if ($c->param('submit_changes') && !$error) {

		my $oldAssignmentType = $setRecord->assignment_type();

		# Save general set information (including headers)

		if ($forUsers) {
			# Note that we don't deal with the proctor user fields here, with the assumption that it can't be possible
			# to change them for users.
			# FIXME: This is not the most robust treatment of the problem

			my @userRecords = $db->getUserSetsWhere({ user_id => [@editForUser], set_id => $setID });
			# If editing a set version, we want to edit that instead of the userset, so get it too.
			my $userSet    = $userRecords[0];
			my $setVersion = 0;
			if ($editingSetVersion) {
				$setVersion  = $db->getSetVersion($editForUser[0], $setID, $editingSetVersion);
				@userRecords = ($setVersion);
			}

			for my $record (@userRecords) {
				for my $field (@{ SET_FIELDS() }) {
					next unless canChange($forUsers, $field);

					my $param = $c->param("set.$setID.$field");
					if ($param && $param ne '') {
						$param = $undoLabels{$field}{$param}               if defined $undoLabels{$field}{$param};
						$param = $param * $properties{$field}->{convertby} if $properties{$field}{convertby};

						# Special case: Does field fill in multiple values?
						if ($field =~ /:/) {
							my @values = split(/:/, $param);
							my @fields = split(/:/, $field);
							for (0 .. $#values) {
								my $f = $fields[$_];
								$record->$f($values[$_]);
							}
						} else {
							$record->$field($param);
						}
					} else {
						if ($field =~ /:/) { $record->$_(undef) for split(/:/, $field) }
						else               { $record->$field(undef) }
					}
				}

				if   ($editingSetVersion) { $db->putSetVersion($record) }
				else                      { $db->putUserSet($record) }
			}

			# Save IP restriction Location information
			# FIXME: it would be nice to have this in the field values hash, so that we don't have to assume that we can
			# override this information for users.

			# Should we allow resetting set locations for set versions?  This requires either putting in a new set of
			# database routines to deal with the versioned setID, or fudging it at this end by manually putting in the
			# versioned ID setID,v#.  Neither of these seems desirable, so for now it's not allowed
			if (!$editingSetVersion) {
				my @selectedLocations = grep { $_ ne '' } $c->param("set.$setID.selected_ip_locations");
				if (@selectedLocations) {
					for my $record (@userRecords) {
						my $userID           = $record->user_id;
						my @userSetLocations = $db->listUserSetLocations($userID, $setID);
						my @addSetLocations;
						my @delSetLocations;
						for my $loc (@selectedLocations) {
							push(@addSetLocations, $loc) if (!grep {/^$loc$/} @userSetLocations);
						}
						for my $loc (@userSetLocations) {
							push(@delSetLocations, $loc) if (!grep {/^$loc$/} @selectedLocations);
						}
						# Update the user set_locations
						for (@addSetLocations) {
							my $Loc = $db->newUserSetLocation;
							$Loc->set_id($setID);
							$Loc->user_id($userID);
							$Loc->location_id($_);
							$db->addUserSetLocation($Loc);
						}
						for (@delSetLocations) {
							$db->deleteUserSetLocation($userID, $setID, $_);
						}
					}
				} else {
					# If no sets were selected, then make sure that there are no set_locations_user entries.
					for my $record (@userRecords) {
						my $userID        = $record->user_id;
						my @userLocations = $db->listUserSetLocations($userID, $setID);
						for (@userLocations) {
							$db->deleteUserSetLocation($userID, $setID, $_);
						}
					}
				}
			}
		} else {
			foreach my $field (@{ SET_FIELDS() }) {
				next unless canChange($forUsers, $field);

				my $param = $c->param("set.$setID.$field");
				$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : ""
					unless defined $param && $param ne "";
				my $unlabel = $undoLabels{$field}->{$param};
				$param = $unlabel if defined $unlabel;
				if ($field =~ /restricted_release/ && $param) {
					$param = format_set_name_internal($param =~ s/\s*,\s*/,/gr);
					$c->check_sets($db, $param);
				}
				if ($properties{$field}->{convertby} && $param) {
					$param = $param * $properties{$field}->{convertby};
				}

				if ($field =~ /:/) {
					my @values = split(/:/, $param);
					my @fields = split(/:/, $field);
					for (my $i = 0; $i < @fields; $i++) {
						my $f = $fields[$i];
						$setRecord->$f($values[$i]);
					}
				} else {
					$setRecord->$field($param);
				}
			}
			$db->putGlobalSet($setRecord);

			# Save IP restriction Location information
			if (defined($c->param("set.$setID.restrict_ip")) && $c->param("set.$setID.restrict_ip") ne 'No') {
				my @selectedLocations  = $c->param("set.$setID.selected_ip_locations");
				my @globalSetLocations = $db->listGlobalSetLocations($setID);
				my @addSetLocations    = ();
				my @delSetLocations    = ();
				foreach my $loc (@selectedLocations) {
					push(@addSetLocations, $loc) if (!grep {/^$loc$/} @globalSetLocations);
				}
				foreach my $loc (@globalSetLocations) {
					push(@delSetLocations, $loc) if (!grep {/^$loc$/} @selectedLocations);
				}
				# Update the global set_locations
				foreach (@addSetLocations) {
					my $Loc = $db->newGlobalSetLocation;
					$Loc->set_id($setID);
					$Loc->location_id($_);
					$db->addGlobalSetLocation($Loc);
				}
				foreach (@delSetLocations) {
					$db->deleteGlobalSetLocation($setID, $_);
				}
			} else {
				my @globalSetLocations = $db->listGlobalSetLocations($setID);
				foreach (@globalSetLocations) {
					$db->deleteGlobalSetLocation($setID, $_);
				}
			}

			# Save proctored problem proctor user information
			if ($c->param("set.$setID.restricted_login_proctor_password")
				&& $setRecord->assignment_type eq 'proctored_gateway')
			{
				# In this case add a set-level proctor or update the password.
				my $procID = "set_id:$setID";
				my $pass   = $c->param("set.$setID.restricted_login_proctor_password");
				# Should we carefully check in this case that the user and password exist?  The code in the add stanza
				# is pretty careful to be sure that there's a one-to-one correspondence between the existence of the
				# user and the setting of the set restricted_login_proctor field, so we assume that just checking the
				# latter here is sufficient.
				if ($setRecord->restricted_login_proctor eq 'Yes') {
					if ($pass ne '********') {
						# A new password was submitted. So save it.
						my $dbPass = eval { $db->getPassword($procID) };
						if ($@) {
							$c->addbadmessage($c->maketext(
								'Error getting old set-proctor password from the database: [_1].  '
									. 'No update to the password was done.',
								$@
							));
						} else {
							$dbPass->password(cryptPassword($pass));
							$db->putPassword($dbPass);
						}
					}
				} else {
					$setRecord->restricted_login_proctor('Yes');
					my $procUser = $db->newUser();
					$procUser->user_id($procID);
					$procUser->last_name("Proctor");
					$procUser->first_name("Login");
					$procUser->student_id("loginproctor");
					$procUser->status($ce->status_name_to_abbrevs('Proctor'));
					my $procPerm = $db->newPermissionLevel;
					$procPerm->user_id($procID);
					$procPerm->permission($ce->{userRoles}{login_proctor});
					my $procPass = $db->newPassword;
					$procPass->user_id($procID);
					$procPass->password(cryptPassword($pass));

					eval { $db->addUser($procUser) };
					if ($@) {
						$c->addbadmessage($c->maketext("Error adding set-level proctor: [_1]", $@));
					} else {
						$db->addPermissionLevel($procPerm);
						$db->addPassword($procPass);
					}

					# Set the restricted_login_proctor set field
					$db->putGlobalSet($setRecord);
				}

			} else {
				# If the parameter isn't set, or if the assignment type is not 'proctored_gateway', then ensure that
				# there is no set-level proctor defined.
				if ($setRecord->restricted_login_proctor eq 'Yes') {

					$setRecord->restricted_login_proctor('No');
					$db->deleteUser("set_id:$setID");
					$db->putGlobalSet($setRecord);

				}
			}
		}

		# Save problem information

		my @problemIDs     = map { $_->[1] } $db->listGlobalProblemsWhere({ set_id => $setID }, 'problem_id');
		my @problemRecords = $db->getGlobalProblems(map { [ $setID, $_ ] } @problemIDs);
		foreach my $problemRecord (@problemRecords) {
			my $problemID = $problemRecord->problem_id;
			die $c->maketext("Global problem [_1] for set [_2] not found.", $problemID, $setID) unless $problemRecord;

			if ($forUsers) {
				# Since we're editing for specific users, we don't allow the GlobalProblem record to be altered on that
				# same page So we only need to make changes to the UserProblem record and only then if we are overriding
				# a value in the GlobalProblem record or for fields unique to the UserProblem record.

				my @userIDs = @editForUser;

				my @userProblemRecords;
				if (!$editingSetVersion) {
					my @userProblemIDs = map { [ $_, $setID, $problemID ] } @userIDs;
					@userProblemRecords = $db->getUserProblemsWhere(
						{ user_id => [@userIDs], set_id => $setID, problem_id => $problemID });
				} else {
					## (we know that we're only editing for one user)
					@userProblemRecords =
						($db->getMergedProblemVersion($userIDs[0], $setID, $editingSetVersion, $problemID));
				}

				foreach my $record (@userProblemRecords) {
					my $changed = 0;    # Keep track of changes. If none are made, avoid unnecessary db accesses.

					for my $field (@{ PROBLEM_FIELDS() }) {
						next unless canChange($forUsers, $field);

						my $param = $c->param("problem.$problemID.$field");
						if (defined $param && $param ne '') {
							$param = $undoLabels{$field}{$param} if defined $undoLabels{$field}{$param};

							# Protect exploits with source_file
							if ($field eq 'source_file') {
								if ($param =~ /\.\./ || $param =~ /^\//) {
									$c->addbadmessage($c->maketext(
										'Source file paths cannot include .. or start with /: '
											. 'your source file path was modified.'
									));
								}
								$param =~ s|\.\.||g;    # prevent access to files above template
								$param =~ s|^/||;       # prevent access to files above template
							}

							$changed ||= changed($record->$field, $param);
							$record->$field($param);
						} else {
							$changed ||= changed($record->$field, undef);
							$record->$field(undef);
						}
					}

					for my $field (@{ USER_PROBLEM_FIELDS() }) {
						next unless canChange($forUsers, $field);

						my $param = $c->param("problem.$problemID.$field");
						$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : ""
							unless defined $param && $param ne "";
						my $unlabel = $undoLabels{$field}->{$param};
						$param = $unlabel if defined $unlabel;
						# Protect exploits with source_file
						if ($field eq 'source_file') {
							if ($param =~ /\.\./ || $param =~ /^\//) {
								$c->addbadmessage($c->maketext(
									'Source file paths cannot include .. or start with /: '
										. 'your source file path was modified.'
								));
							}
							$param =~ s|\.\.||g;    # prevent access to files above template
							$param =~ s|^/||;       # prevent access to files above template
						}

						$changed ||= changed($record->$field, $param);
						$record->$field($param);
					}

					if (!$editingSetVersion) {
						$db->putUserProblem($record) if $changed;
					} else {
						$db->putProblemVersion($record) if $changed;
					}
				}
			} else {
				# Since we're editing for ALL set users, we will make changes to the GlobalProblem record.
				# We may also have instances where a field is unique to the UserProblem record but we want
				# all users to (at least initially) have the same value

				# This only edits a globalProblem record
				my $changed = 0;    # Keep track of changes. If none are made, avoid unnecessary db accesses.
				foreach my $field (@{ PROBLEM_FIELDS() }) {
					next unless canChange($forUsers, $field);

					my $param = $c->param("problem.$problemID.$field");
					$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : ""
						unless defined $param && $param ne "";
					my $unlabel = $undoLabels{$field}->{$param};
					$param = $unlabel if defined $unlabel;

					# Protect exploits with source_file
					if ($field eq 'source_file') {
						if ($param =~ /\.\./ || $param =~ /^\//) {
							$c->addbadmessage($c->maketext(
								'Source file paths cannot include .. or start with /: '
									. 'your source file path was modified.'
							));
						}
						$param =~ s|\.\.||g;    # prevent access to files above template
						$param =~ s|^/||;       # prevent access to files above template
					}
					$changed ||= changed($problemRecord->$field, $param);
					$problemRecord->$field($param);
				}
				$db->putGlobalProblem($problemRecord) if $changed;

				# Sometimes (like for status) we might want to change an attribute in the userProblem record for every
				# assigned user.  However, since this data is stored in the UserProblem records, it won't be displayed
				# once its been changed, and if you hit "Save Changes" again it gets erased.  So we'll enforce that
				# there be something worth putting in all the UserProblem records.  This also will make hitting "Save
				# Changes" on the global page MUCH faster.
				my %useful;
				foreach my $field (@{ USER_PROBLEM_FIELDS() }) {
					my $param = $c->param("problem.$problemID.$field");
					$useful{$field} = 1 if defined $param and $param ne "";
				}

				if (keys %useful) {
					my @userProblemRecords = $db->getUserProblemsWhere({ set_id => $setID, problem_id => $problemID });
					foreach my $record (@userProblemRecords) {
						my $changed = 0;    # Keep track of changes. If none are made, avoid unnecessary db accesses.
						foreach my $field (keys %useful) {
							next unless canChange($forUsers, $field);

							my $param = $c->param("problem.$problemID.$field");
							$param = defined $properties{$field}->{default} ? $properties{$field}->{default} : ""
								unless defined $param && $param ne "";
							my $unlabel = $undoLabels{$field}->{$param};
							$param = $unlabel if defined $unlabel;
							$changed ||= changed($record->$field, $param);
							$record->$field($param);
						}
						$db->putUserProblem($record) if $changed;
					}
				}
			}
		}

		# Mark the specified problems as correct for all users (not applicable when editing a set version, because this
		# only shows up when editing for users or editing the global set/problem, not for one user)
		for my $problemID ($c->param('markCorrect')) {
			my @userProblemIDs =
				$forUsers
				? (map { [ $_, $setID, $problemID ] } @editForUser)
				: $db->listUserProblemsWhere({ set_id => $setID, problem_id => $problemID });
			# If the set is not a gateway set, this requires going through the user_problems and resetting their status.
			# If it's a gateway set, then we have to go through every *version* of every user_problem.  It may be that
			# there is an argument for being able to get() all problem versions for all users in one database call.  The
			# current code may be slow for large classes.
			if ($setRecord->assignment_type !~ /gateway/) {
				my @userProblemRecords = $db->getUserProblems(@userProblemIDs);
				foreach my $record (@userProblemRecords) {
					if (defined $record && ($record->status eq "" || $record->status < 1)) {
						$record->status(1);
						$record->attempted(1);
						$db->putUserProblem($record);
					}
				}
			} else {
				my @userIDs = $forUsers ? @editForUser : $db->listProblemUsers($setID, $problemID);
				foreach my $uid (@userIDs) {
					my @versions = $db->listSetVersions($uid, $setID);
					my @userProblemVersionIDs =
						map { [ $uid, $setID, $_, $problemID ] } @versions;
					my @userProblemVersionRecords = $db->getProblemVersions(@userProblemVersionIDs);
					foreach my $record (@userProblemVersionRecords) {
						if (defined $record && ($record->status eq "" || $record->status < 1)) {
							$record->status(1);
							$record->attempted(1);
							$db->putProblemVersion($record);
						}
					}
				}
			}
		}

		# Delete all problems marked for deletion (not applicable when editing for users).
		foreach my $problemID ($c->param('deleteProblem')) {
			$db->deleteGlobalProblem($setID, $problemID);

			# If it is a jitar, then delete all of the child problems.
			if ($setRecord->assignment_type eq 'jitar') {
				my @ids        = $db->listGlobalProblems($setID);
				my @problemSeq = jitar_id_to_seq($problemID);
			ID: foreach my $id (@ids) {
					my @seq = jitar_id_to_seq($id);
					# Check and see if this is a child.
					next unless $#seq > $#problemSeq;
					for (my $i = 0; $i <= $#problemSeq; $i++) {
						next ID unless $seq[$i] == $problemSeq[$i];
					}
					$db->deleteGlobalProblem($setID, $id);
				}

			}
		}

		# Change problem_ids from regular style to jitar style if appropraite.  (Not applicable when editing for users.)
		# This is a very long operation because we are shuffling the whole database around.
		if ($oldAssignmentType ne $setRecord->assignment_type
			&& ($oldAssignmentType eq 'jitar' || $setRecord->assignment_type eq 'jitar'))
		{
			my %newProblemNumbers;
			my @ids = $db->listGlobalProblems($setID);
			my $i   = 1;
			foreach my $id (@ids) {

				if ($setRecord->assignment_type eq 'jitar') {
					$newProblemNumbers{$id} = seq_to_jitar_id(($id));
				} else {
					$newProblemNumbers{$id} = $i;
					$i++;
				}
			}

			# we dont want to confuse the script by changing the problem
			# ids out from under it so remove the params
			foreach my $id (@ids) {
				$c->param("prob_num_$id", undef);
			}

			$c->handle_problem_numbers(\%newProblemNumbers, $db, $setID);
		}

		# Reorder problems

		my %newProblemNumbers;
		my $prevNum = 0;
		my @prevSeq = (0);

		for my $jj (sort { $a <=> $b } $db->listGlobalProblems($setID)) {
			if ($setRecord->assignment_type eq 'jitar') {
				my @idSeq;
				my $id = $jj;

				next unless $c->param('prob_num_' . $id);

				unshift @idSeq, $c->param('prob_num_' . $id);
				while (defined $c->param('prob_parent_id_' . $id)) {
					$id = $c->param('prob_parent_id_' . $id);
					unshift @idSeq, $c->param('prob_num_' . $id);
				}

				$newProblemNumbers{$jj} = seq_to_jitar_id(@idSeq);

			} else {
				$newProblemNumbers{$jj} = $c->param('prob_num_' . $jj);
			}
		}

		$c->handle_problem_numbers(\%newProblemNumbers, $db, $setID) unless defined $c->param('undo_changes');

		# Make problem numbers consecutive if required
		if ($c->param('force_renumber')) {
			my %newProblemNumbers = ();
			my $prevNum           = 0;
			my @prevSeq           = (0);

			for my $jj (sort { $a <=> $b } $db->listGlobalProblems($setID)) {
				if ($setRecord->assignment_type eq 'jitar') {
					my @idSeq;
					my $id = $jj;

					next unless $c->param('prob_num_' . $id);

					unshift @idSeq, $c->param('prob_num_' . $id);
					while (defined $c->param('prob_parent_id_' . $id)) {
						$id = $c->param('prob_parent_id_' . $id);
						unshift @idSeq, $c->param('prob_num_' . $id);
					}

					# we dont really care about the content of idSeq
					# in this case, just the length
					my $depth = $#idSeq;

					if ($depth <= $#prevSeq) {
						@prevSeq = @prevSeq[ 0 .. $depth ];
						++$prevSeq[-1];
					} else {
						$prevSeq[ $#prevSeq + 1 ] = 1;
					}

					$newProblemNumbers{$jj} = seq_to_jitar_id(@prevSeq);

				} else {
					$prevNum++;
					$newProblemNumbers{$jj} = $prevNum;
				}
			}

			$c->handle_problem_numbers(\%newProblemNumbers, $db, $setID) unless defined $c->param('undo_changes');
		}

		# Add blank problem if needed
		if (defined($c->param("add_blank_problem")) and $c->param("add_blank_problem") == 1) {
			# Get number of problems to add and clean the entry
			my $newBlankProblems = (defined($c->param("add_n_problems"))) ? $c->param("add_n_problems") : 1;
			$newBlankProblems = int($newBlankProblems);
			my $MAX_NEW_PROBLEMS = 20;
			my @ids              = $c->db->listGlobalProblems($setID);

			if ($setRecord->assignment_type eq 'jitar') {
				for (my $i = 0; $i <= $#ids; $i++) {
					my @seq = jitar_id_to_seq($ids[$i]);
					# This strips off the depth 0 problem numbers if its a jitar set
					$ids[$i] = $seq[0];
				}
			}

			my $targetProblemNumber = WeBWorK::Utils::max(@ids);

			if ($newBlankProblems >= 1 and $newBlankProblems <= $MAX_NEW_PROBLEMS) {
				foreach my $newProb (1 .. $newBlankProblems) {
					$targetProblemNumber++;
					# Make local copy of the blankProblem
					my $blank_file_path = $ce->{webworkFiles}{screenSnippets}{blankProblem};
					my $problemContents = readFile($blank_file_path);
					my $new_file_path   = "set$setID/" . BLANKPROBLEM();
					my $fullPath        = surePathToFile($ce->{courseDirs}{templates}, $new_file_path);

					open(my $TEMPFILE, '>', $fullPath) or warn $c->maketext(q{Can't write to file [_1]}, $fullPath);
					print $TEMPFILE $problemContents;
					close($TEMPFILE);

					# Update problem record
					my $problemRecord = addProblemToSet(
						$db, $ce->{problemDefaults},
						setName    => $setID,
						sourceFile => $new_file_path,
						problemID  => $setRecord->assignment_type eq 'jitar'
						? seq_to_jitar_id(($targetProblemNumber))
						: $targetProblemNumber,
					);

					assignProblemToAllSetUsers($db, $problemRecord);
					$c->addgoodmessage($c->maketext(
						"Added [_1] to [_2] as problem [_3]",
						$new_file_path, $setID, $targetProblemNumber
					));
				}
			} else {
				$c->addbadmessage($c->maketext(
					"Could not add [_1] problems to this set.  The number must be between 1 and [_2]",
					$newBlankProblems, $MAX_NEW_PROBLEMS
				));
			}
		}

		# Sets the specified header to "defaultHeader" so that the default file will get used.
		foreach my $header ($c->param('defaultHeader')) {
			$setRecord->$header("defaultHeader");
		}
	}

	# Check that every user that is being edited has a valid UserSet.
	my @unassignedUsers;
	if (@editForUser) {
		my @assignedUsers;
		for my $ID (@editForUser) {
			if ($db->existsUserSet($ID, $setID)) {
				unshift @assignedUsers, $ID;
			} else {
				unshift @unassignedUsers, $ID;
			}
		}
		@editForUser = sort @assignedUsers;
		$c->param('editForUser', \@editForUser);
	}

	$c->stash->{unassignedUsers} = \@unassignedUsers;

	# Check that if a set version for a user is being edited, that it exists as well
	return if $editingSetVersion && !$db->existsSetVersion($editForUser[0], $setID, $editingSetVersion);

	# Get global problem records for all problems sorted by problem id.
	my @globalProblems = $db->getGlobalProblemsWhere({ set_id => $setID }, 'problem_id');
	$c->stash->{problemIDList}  = [ map { $_->problem_id } @globalProblems ];
	$c->stash->{globalProblems} = { map { $_->problem_id => $_ } @globalProblems };

	# If editing for one user, get user problem records for all problems.  Note that merged problems are not needed.  We
	# have the global problem, the user problem, and for test versions, the problem versions.  Those have everything the
	# merged problem has.  It does take a bit more work to find the merge value from the three.
	if (@editForUser == 1) {
		$c->stash->{userProblems} = { map { $_->problem_id => $_ }
				$db->getUserProblemsWhere({ user_id => $editForUser[0], set_id => $setID }) };

		# If this is a test version, then also get the problem versions for that test version.
		if ($editingSetVersion) {
			$c->stash->{userProblemVersions} = {
				map { $_->problem_id => $_ } $db->getProblemVersionsWhere(
					{ user_id => $editForUser[0], set_id => "$setID,v$editingSetVersion" }
				)
			};
		}
	}

	# Reset all the parameters dealing with set/problem/header information.  It may not be obvious why this is necessary
	# when saving changes, but when the problems are reordered the param problem.1.source_file needs to be the source
	# file of the problem that is NOW #1 and not the problem that WAS #1.
	for my $param ($c->param) {
		$c->param($param, undef) if $param =~ /^(set|problem|header)\./ && $param !~ /displaymode/;
	}

	# Reset checkboxes that should always be unchecked when the page loads.
	$c->param('deleteProblem',     undef);
	$c->param('markCorrect',       undef);
	$c->param('force_renumber',    undef);
	$c->param('add_blank_problem', undef);

	return;
}

# Helper method for checking if two values are different.
# The return values will usually be thrown away, but they could be useful for debugging.
sub changed ($first, $second) {
	return "def/undef" if defined $first  && !defined $second;
	return "undef/def" if !defined $first && defined $second;
	return ""          if !defined $first && !defined $second;
	return "ne"        if $first ne $second;
	return "";
}

# Helper method that determines for how many users at a time a field can be changed.
# 	none means it can't be changed for anyone
# 	any means it can be changed for anyone
# 	one means it can ONLY be changed for one at a time. (eg problem_seed)
# 	all means it can ONLY be changed for all at a time. (eg set_header)
sub canChange ($forUsers, $field) {
	my %properties = %{ FIELD_PROPERTIES() };
	my $forOneUser = $forUsers == 1;

	my $howManyCan = $properties{$field}{override};
	return 0 if $howManyCan eq "none";
	return 1 if $howManyCan eq "any";
	return 1 if $howManyCan eq "one" && $forOneUser;
	return 1 if $howManyCan eq "all" && !$forUsers;
	return 0;    # FIXME: maybe it should default to 1?
}

# Helper method that determines if a file is valid and returns a pretty error message.
sub checkFile ($c, $filePath, $headerType) {
	my $ce = $c->ce;

	return $c->maketext("No source filePath specified") unless $filePath;
	return $c->maketext("Problem source is drawn from a grouping set") if $filePath =~ /^group/;

	if ($filePath eq "defaultHeader") {
		if ($headerType eq 'set_header') {
			$filePath = $ce->{webworkFiles}{screenSnippets}{setHeader};
		} elsif ($headerType eq 'hardcopy_header') {
			$filePath = $ce->{webworkFiles}{hardcopySnippets}{setHeader};
		} else {
			return $c->maketext("Invalid headerType [_1]", $headerType);
		}
	} else {
		# Only filePaths in the template directory can be accessed.
		$filePath = "$ce->{courseDirs}{templates}/$filePath";
	}

	my $fileError;
	return ""                                                if -e $filePath && -f $filePath && -r $filePath;
	return $c->maketext("This source file is not readable!") if -e $filePath && -f $filePath;
	return $c->maketext("This source file is a directory!")  if -d $filePath;
	return $c->maketext("This source file does not exist!") unless -e $filePath;
	return $c->maketext("This source file is not a plain file!");
}

# Make sure restrictor sets exist.
sub check_sets ($c, $db, $sets_string) {
	my @proposed_sets = split(/\s*,\s*/, $sets_string);
	for (@proposed_sets) {
		$c->addbadmessage("Error: $_ is not a valid set name in restricted release list!")
			unless $db->existsGlobalSet($_);
	}

	return;
}

sub userCountMessage ($c, $count, $numUsers) {
	if ($count == 0) {
		return $c->tag('em', $c->maketext('no students'));
	} elsif ($count == $numUsers) {
		return $c->maketext('all students');
	} elsif ($count == 1) {
		return $c->maketext('1 student');
	} elsif ($count > $numUsers || $count < 0) {
		return $c->tag('em', $c->maketext('an impossible number of users: [_1] out of [_2]', $count, $numUsers));
	} else {
		return $c->maketext('[_1] students out of [_2]', $count, $numUsers);
	}
}

sub setCountMessage ($c, $count, $numSets) {
	if ($count == 0) {
		return $c->tag('em', $c->maketext('no sets'));
	} elsif ($count == $numSets) {
		return $c->maketext('all sets');
	} elsif ($count == 1) {
		return $c->maketext('1 set');
	} elsif ($count > $numSets || $count < 0) {
		return $c->tag('em', $c->maketext('an impossible number of sets: [_1] out of [_2]', $count, $numSets));
	} else {
		return $c->maketext('[_1] sets', $count);
	}
}

1;
