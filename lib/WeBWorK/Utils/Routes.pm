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

package WeBWorK::Utils::Routes;
use parent qw(Exporter);

=head1 NAME

WeBWorK::Utils::Routes - webwork2 route parameters and route utility methods.

=head1 ROUTES

PLEASE FOR THE LOVE OF GOD UPDATE THIS IF YOU CHANGE THE ROUTES BELOW!!!

 root                                /

 course_admin                        /$ce->{admin_course_id} -> logout, options, instructor_tools

 render_rpc                          /render_rpc
 instructor_rpc                      /instructor_rpc
 html2xml                            /html2xml

 ltiadvanced_content_selection       /ltiadvanced/content_selection

 ltiadvantage_login                  /ltiadvantage/login
 ltiadvantage_launch                 /ltiadvantage/launch
 ltiadvantage_keys                   /ltiadvantage/keys
 ltiadvantage_content_selection      /ltiadvantage/content_selection

 pod_index                           /pod
 pod_viewer                          /pod/$filePath

 sample_problem_index                /sampleproblems
 sample_problem_viewer               /sampleproblems/$filePath

 set_list                            /$courseID

 logout                              /$courseID/logout
 options                             /$courseID/options
 grades                              /$courseID/grades
 achievements                        /$courseID/achievements
 achievements_leaderboard            /$courseID/achievements/leaderboard
 equation_display                    /$courseID/equation
 feedback                            /$courseID/feedback
 gateway_quiz                        /$courseID/test_mode/$setID

 proctored_gateway_quiz              /$courseID/proctored_test_mode/$setID
 proctored_gateway_proctor_login     /$courseID/proctored_test_mode/$setID/proctor_login

 hardcopy                            /$courseID/hardcopy
 hardcopy_preselect_set              /$courseID/hardcopy/$setID

 answer_log                          /$courseID/show_answers

 instructor_tools                    /$courseID/instructor

 instructor_user_list                /$courseID/instructor/users
 instructor_user_detail              /$courseID/instructor/users/$userID

 instructor_set_list                 /$courseID/instructor/sets

 instructor_set_detail               /$courseID/instructor/sets/$setID
 instructor_users_assigned_to_set    /$courseID/instructor/sets/$setID/users

 instructor_problem_grader           /$courseID/instructor/grader/$setID/$problemID

 instructor_add_users                /$courseID/instructor/add_users
 instructor_set_assigner             /$courseID/instructor/assigner

 instructor_set_maker                /$courseID/instructor/setmaker
 instructor_file_manager             /$courseID/instructor/file_manager
 instructor_config                   /$courseID/instructor/config

 instructor_problem_editor           /$courseID/instructor/pgProblemEditor
 instructor_problem_editor_withset   /$courseID/instructor/pgProblemEditor/$setID
 instructor_problem_editor_withset_withproblem
                                     /$courseID/instructor/pgProblemEditor/$setID/$problemID

 instructor_scoring                  /$courseID/instructor/scoring
 instructor_scoring_download         /$courseID/instructor/scoringDownload
 instructor_mail_merge               /$courseID/instructor/send_mail

 instructor_statistics               /$courseID/instructor/stats
 instructor_set_statistics           /$courseID/instructor/stats/set/$setID
 instructor_problem_statistics       /$courseID/instructor/stats/set/$setID/$problemID
 instructor_user_statistics          /$courseID/instructor/stats/student/$userID

 instructor_progress                 /$courseID/instructor/progress
 instructor_set_progress             /$courseID/instructor/progress/set/$setID
 instructor_user_progress            /$courseID/instructor/progress/student/$userID

 instructor_achievement_list         /$courseID/instructor/achievement_list
 instructor_achievement_editor       /$courseID/instructor/achievement_list/$achievementID/editor
 instructor_achievement_user_editor  /$courseID/instructor/achievement_list/$achievementID/users
 instructor_achievement_notification /$courseID/instructor/achievement_list/$achievementID/email

 instructor_lti_update               /$courseID/instructor/lti_update

 instructor_job_manager              /$courseID/instructor/job_manager

 problem_list                        /$courseID/$setID
 problem_detail                      /$courseID/$setID/$problemID
 show_me_another                     /$courseID/$setID/$problemID/show_me_another

=cut

use strict;
use warnings;

use WeBWorK::Localize;
use WeBWorK::Utils qw(x);
use WeBWorK::Utils::Sets qw(format_set_name_display);

our @EXPORT_OK = qw(setup_content_generator_routes route_title route_navigation_is_restricted);

# Tree of route parameters.
# Parameters:
#   title:        Used to construct a title for the page the route generates. This is required.
#   children:     Child routes. These must have a url path below the parent. A route that does not have children should
#                 not have this parameter.
#   module:       The content generator controller module that contains the action for the route. This is required.
#   path:         The path of the route relative to the parent route.  This includes route capture parameters.
#                 This is required.
#   unrestricted: If a route has the "unrestricted" flag, then all users can visit that route. Users that do not have
#                 the "navigation_allowed" permission may not visit routes that do not have the "unrestricted" flag.

# Note for the localization
# [_1] = $userID
# [_2] = $setID
# [_3] = $problemID
# [_4] = $courseID
# [_5] = $achievementID

my %routeParameters = (
	root => {
		title => 'WeBWorK',
		# 'course_admin' is also a child of 'root' but that is a special case that is setup separately.
		children => [ qw(
			render_rpc
			html2xml
			instructor_rpc
			ltiadvanced_content_selection
			ltiadvantage_login
			ltiadvantage_launch
			ltiadvantage_keys
			ltiadvantage_content_selection
			pod_index
			sample_problem_index
			set_list
		) ],
		module => 'Home',
		path   => '/'
	},

	course_admin => {
		title  => x('Course Administration'),
		module => 'CourseAdmin',
		path   => '/$ce->{admin_course_id}'
	},

	render_rpc => {
		title  => 'render_rpc',
		module => 'RenderViaRPC',
		path   => '/render_rpc'
	},
	instructor_rpc => {
		title  => 'instructor_rpc',
		module => 'InstructorRPCHandler',
		path   => '/instructor_rpc'
	},

	# The html2xml route is an deprecated alias to the render_rpc route above.
	# It no longer has anything to do with xml, and so the route title does not make sense anymore.
	html2xml => {
		title  => 'html2xml',
		module => 'RenderViaRPC',
		path   => '/html2xml'
	},

	ltiadvanced_content_selection => {
		title  => x('Content Selection'),
		module => 'LTIAdvanced',
		path   => '/ltiadvanced/content_selection',
		action => 'content_selection'
	},

	# Both of these routes end up at the login screen on failure, and the title is not used anywhere else.
	# Hence the title 'Login'.
	ltiadvantage_login => {
		title  => x('Login'),
		module => 'LTIAdvantage',
		path   => '/ltiadvantage/login',
		action => 'login'
	},
	ltiadvantage_launch => {
		title  => x('Login'),
		module => 'LTIAdvantage',
		path   => '/ltiadvantage/launch',
		action => 'launch'
	},
	ltiadvantage_keys => {
		title  => 'keys',
		module => 'LTIAdvantage',
		path   => '/ltiadvantage/keys',
		action => 'keys'
	},
	ltiadvantage_content_selection => {
		title  => x('Content Selection'),
		module => 'LTIAdvantage',
		path   => '/ltiadvantage/content_selection',
		action => 'content_selection'
	},

	pod_index => {
		title    => x('POD Index'),
		children => [qw(pod_viewer)],
		module   => 'PODViewer',
		path     => '/pod',
		action   => 'PODindex'
	},

	pod_viewer => {
		title  => x('POD Viewer'),
		module => 'PODViewer',
		path   => '/*filePath',
		action => 'renderPOD'
	},

	sample_problem_index => {
		title    => x('Sample Problem Index'),
		children => [qw(sample_problem_viewer)],
		module   => 'SampleProblemViewer',
		path     => '/sampleproblems',
		action   => 'sampleProblemIndex'
	},

	sample_problem_viewer => {
		title  => x('Sample Problem Viewer'),
		module => 'SampleProblemViewer',
		path   => '/*filePath',
		action => 'renderSampleProblem'
	},

	set_list => {
		title    => '[_4]',
		children => [
			qw(equation_display feedback gateway_quiz proctored_gateway_quiz answer_log grades hardcopy achievements
				logout options instructor_tools problem_list)
		],
		module => 'ProblemSets',
		path   => '/#courseID'
	},

	logout => {
		title  => x('Logout'),
		module => 'Logout',
		path   => '/logout'
	},
	options => {
		title        => x('Account Settings'),
		module       => 'Options',
		path         => '/options',
		unrestricted => 1
	},
	grades => {
		title  => x('Grades'),
		module => 'Grades',
		path   => '/grades'
	},
	achievements => {
		title        => x('Achievements'),
		children     => [qw(achievements_leaderboard)],
		module       => 'Achievements',
		path         => '/achievements',
		unrestricted => 1
	},
	achievements_leaderboard => {
		title        => x('Achievements Leaderboard'),
		module       => 'AchievementsLeaderboard',
		path         => '/leaderboard',
		unrestricted => 1
	},
	equation_display => {
		title  => x('Equation Display'),
		module => 'EquationDisplay',
		path   => '/equation'
	},
	feedback => {
		title        => x('Feedback'),
		module       => 'Feedback',
		path         => '/feedback',
		unrestricted => 1
	},
	gateway_quiz => {
		title        => x('Test [_2]'),
		module       => 'GatewayQuiz',
		path         => '/test_mode/#setID',
		unrestricted => 1
	},

	proctored_gateway_quiz => {
		title        => x('Proctored Test [_2]'),
		children     => [qw(proctored_gateway_proctor_login)],
		module       => 'ProctoredGatewayQuiz',
		path         => '/proctored_test_mode/#setID',
		unrestricted => 1
	},
	proctored_gateway_proctor_login => {
		title        => x('Proctored Test [_2] Proctor Login'),
		module       => 'LoginProctor',
		path         => '/proctor_login',
		unrestricted => 1
	},

	hardcopy => {
		title    => x('Hardcopy Generator'),
		children => [qw(hardcopy_preselect_set)],
		module   => 'Hardcopy',
		path     => '/hardcopy'
	},
	hardcopy_preselect_set => {
		title        => x('Hardcopy Generator'),
		module       => 'Hardcopy',
		path         => '/#setID',
		unrestricted => 1
	},

	answer_log => {
		title  => x('Answer Log'),
		module => 'Instructor::ShowAnswers',
		path   => '/show_answers'
	},

	instructor_tools => {
		title    => x('Instructor Tools'),
		children => [ qw(
			instructor_user_list instructor_set_list
			instructor_add_users instructor_achievement_list
			instructor_set_assigner instructor_file_manager
			instructor_problem_editor
			instructor_set_maker
			instructor_config
			instructor_scoring instructor_scoring_download instructor_mail_merge
			instructor_statistics
			instructor_progress
			instructor_problem_grader
			instructor_lti_update
			instructor_job_manager
		) ],
		module => 'Instructor::Index',
		path   => '/instructor'
	},
	instructor_user_list => {
		title    => x('Accounts Manager'),
		children => [qw(instructor_user_detail)],
		module   => 'Instructor::UserList',
		path     => '/users'
	},
	instructor_user_detail => {
		title  => x('Sets assigned to [_1]'),
		module => 'Instructor::UserDetail',
		path   => '/#userID'
	},
	instructor_set_list => {
		title    => x('Sets Manager'),
		children => [qw(instructor_set_detail)],
		module   => 'Instructor::ProblemSetList',
		path     => '/sets'
	},
	instructor_set_detail => {
		title    => x('Set Detail for set [_2]'),
		children => [qw(instructor_users_assigned_to_set)],
		module   => 'Instructor::ProblemSetDetail',
		path     => '/#setID'
	},
	instructor_users_assigned_to_set => {
		title  => x('Users Assigned to Set [_2]'),
		module => 'Instructor::UsersAssignedToSet',
		path   => '/users'
	},
	instructor_problem_grader => {
		title  => x('Manual Grader'),
		module => 'Instructor::ProblemGrader',
		path   => '/grader/#setID/#problemID'
	},
	instructor_add_users => {
		title  => x('Add Users'),
		module => 'Instructor::AddUsers',
		path   => '/add_users'
	},
	instructor_set_assigner => {
		title  => x('Assigner Tool'),
		module => 'Instructor::Assigner',
		path   => '/assigner'
	},
	instructor_set_maker => {
		title  => x('Library Browser'),
		module => 'Instructor::SetMaker',
		path   => '/setmaker'
	},
	instructor_file_manager => {
		title  => x('File Manager'),
		module => 'Instructor::FileManager',
		path   => '/file_manager'
	},
	instructor_config => {
		title  => x('Course Configuration'),
		module => 'Instructor::Config',
		path   => '/config'
	},
	instructor_problem_editor => {
		title    => x('Problem Editor'),
		children => [qw(instructor_problem_editor_withset)],
		module   => 'Instructor::PGProblemEditor',
		path     => '/pgProblemEditor'
	},
	instructor_problem_editor_withset => {
		title    => '[_2]',
		children => [qw(instructor_problem_editor_withset_withproblem)],
		module   => 'Instructor::PGProblemEditor',
		path     => '/#setID'
	},
	instructor_problem_editor_withset_withproblem => {
		title  => '[_3]',
		module => 'Instructor::PGProblemEditor',
		path   => '/#problemID'
	},
	instructor_scoring => {
		title  => x('Scoring Tools'),
		module => 'Instructor::Scoring',
		path   => '/scoring'
	},
	instructor_scoring_download => {
		title  => x('Scoring Download'),
		module => 'Instructor::ScoringDownload',
		path   => '/scoringDownload'
	},
	instructor_mail_merge => {
		title  => x('Email'),
		module => 'Instructor::SendMail',
		path   => '/send_mail'
	},
	instructor_statistics => {
		title    => x('Statistics'),
		children => [qw(instructor_set_statistics instructor_user_statistics)],
		module   => 'Instructor::Stats',
		path     => '/stats'
	},
	instructor_set_statistics => {
		title    => '[_2]',
		children => [qw(instructor_problem_statistics)],
		module   => 'Instructor::Stats',
		path     => '/set/#setID'
	},
	instructor_problem_statistics => {
		title  => '[_3]',
		module => 'Instructor::Stats',
		path   => '/#problemID'
	},
	instructor_user_statistics => {
		title  => '[_1]',
		module => 'Instructor::Stats',
		path   => '/student/#userID'
	},
	instructor_progress => {
		title    => x('Student Progress'),
		children => [qw(instructor_set_progress instructor_user_progress)],
		module   => 'Instructor::StudentProgress',
		path     => '/progress'
	},
	instructor_set_progress => {
		title  => '[_2]',
		module => 'Instructor::StudentProgress',
		path   => '/set/#setID'
	},
	instructor_user_progress => {
		title  => '[_1]',
		module => 'Instructor::StudentProgress',
		path   => '/student/#userID'
	},
	instructor_achievement_list => {
		title    => x('Achievements Manager'),
		children =>
			[qw(instructor_achievement_editor instructor_achievement_user_editor instructor_achievement_notification)],
		module => 'Instructor::AchievementList',
		path   => '/achievement_list'
	},
	instructor_achievement_editor => {
		title  => 'Achievement Evaluator for achievement [_5]',
		module => 'Instructor::AchievementEditor',
		path   => '/#achievementID/editor'
	},
	instructor_achievement_user_editor => {
		title  => x('Achievement Users for [_5]'),
		module => 'Instructor::AchievementUserEditor',
		path   => '/#achievementID/users'
	},
	instructor_achievement_notification => {
		title  => x('Achievement Notification for [_5]'),
		module => 'Instructor::AchievementNotificationEditor',
		path   => '/#achievementID/email'
	},
	instructor_lti_update => {
		title  => x('LTI Grade Update'),
		module => 'Instructor::LTIUpdate',
		path   => '/lti_update'
	},
	instructor_job_manager => {
		title  => x('Job Manager'),
		module => 'Instructor::JobManager',
		path   => '/job_manager'
	},

	problem_list => {
		title        => '[_2]',
		children     => [qw(problem_detail)],
		module       => 'ProblemSet',
		path         => '/#setID',
		unrestricted => 1
	},
	problem_detail => {
		title        => '[_3]',
		children     => [qw(show_me_another)],
		module       => 'Problem',
		path         => '/#problemID',
		unrestricted => 1
	},
	show_me_another => {
		title        => x('Show Me Another'),
		module       => 'ShowMeAnother',
		path         => '/show_me_another',
		unrestricted => 1
	}
);

=head1 METHODS

=head2 Route setup methods

These methods initialize the webwork2 app Mojolicious router for content
generator routes.

=over

=item setup_content_generator_routes

This is the actual method called by Mojolicious::WeBWorK.

=item setup_content_generator_routes_recursive

This is an internal utility method called by the above method.
It is not exported.  It recursively sets up all routes.

=back

=cut

sub setup_content_generator_routes {
	my $route = shift;
	for (@{ $routeParameters{root}{children} }) {
		setup_content_generator_routes_recursive($route, $_);
	}
	return;
}

sub setup_content_generator_routes_recursive {
	my ($route, $child) = @_;

	my $action = $routeParameters{$child}{action} // 'go';

	if ($routeParameters{$child}{children}) {
		my $child_route = $route->under($routeParameters{$child}{path}, [ problemID => qr/\d+/ ])->name($child);
		$child_route->any('/')->to("$routeParameters{$child}{module}#$action")->name($child);
		for (@{ $routeParameters{$child}{children} }) {
			setup_content_generator_routes_recursive($child_route, $_);
		}
	} else {
		$route->any($routeParameters{$child}{path}, [ problemID => qr/\d+/ ])
			->to("$routeParameters{$child}{module}#$action")->name($child);
	}

	return;
}

=head2 Methods that return information about a route.

=over

=item route_title

Returns the human-readable name of the route given by name.  This displays set
ids and course ids with spaces instead of underscores, and if C<$displayHTML> is
true, it places the set id into an ltr span so that it is displayed ltr even for
rtl languages.  Note that the return value of this method should never be used
to determine what type of path this is or for any sort of further processing.
It is a translated string.

=cut

sub route_title {
	my ($c, $route_name, $displayHTML) = @_;

	# Translate the display name.
	my $name = $c->maketext(
		$routeParameters{$route_name}{title},
		$c->stash('userID') // '',
		$displayHTML
		? $c->tag('span', dir => 'ltr', format_set_name_display($c->stash('setID') // ''))
		: format_set_name_display($c->stash('setID') // ''),
		$c->stash('problemID') // '',
		($c->stash('courseID') // '') =~ s/_/ /gr,
		$c->stash('achievementID') // ''
	);

	return $name;
}

=item route_navigation_is_restricted

Returns 1 if the route is restricted from being viewed by a user that does not
have the navigation_allowed permission, and 0 otherwise.  The allowed paths for
restricted users are marked with the unrestricted flag.

=back

=cut

sub route_navigation_is_restricted {
	my $route = shift;
	return defined $routeParameters{ $route->name }{unrestricted} ? 0 : 1;
}

1;
