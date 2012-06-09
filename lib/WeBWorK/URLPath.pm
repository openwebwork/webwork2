################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://github.com/openwebwork
# $CVSHeader: webwork2/lib/WeBWorK/URLPath.pm,v 1.36 2008/04/29 19:27:34 sh002i Exp $
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

package WeBWorK::URLPath;

=head1 NAME

WeBWorK::URLPath - the WeBWorK virtual URL heirarchy.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::Debug;
use WeBWorK::Localize;
{
	no warnings "redefine";
	
	sub debug {
		my ($label, $indent, @message) = @_;
		my $header = " "x$indent;
		$header .= "$label: " if $label ne "";
		WeBWorK::Debug::debug($header, @message);
	}
}

=head1 VIRTUAL HEIRARCHY

PLEASE FOR THE LOVE OF GOD UPDATE THIS IF YOU CHANGE THE HEIRARCHY BELOW!!!

 root                                /
 
 course_admin                        /admin/ -> logout, options, instructor_tools
 html2xml                            /html2xml/
 instructorXMLHandler     			     /instructorXMLHandler/
 set_list                            /$courseID/
 
 equation_display                    /$courseID/equation/
 feedback                            /$courseID/feedback/
 gateway_quiz                        /$courseID/quiz_mode/$setID/
 proctored_gateway_quiz              /$courseID/proctored_quiz_mode/$setID/
 proctored_gateway_proctor_login     /$courseID/proctored_quiz_mode/$setID/proctor_login/
 grades                              /$courseID/grades/
 hardcopy                            /$courseID/hardcopy/
 hardcopy_preselect_set              /$courseID/hardcopy/$setID/
 logout                              /$courseID/logout/
 options                             /$courseID/options/
 #test                               /$courseID/test/
 #render                              /$courseID/render/
 
 instructor_tools                    /$courseID/instructor/
 
 instructor_user_list                /$courseID/instructor/users/
 instructor_user_detail              /$courseID/instructor/users/$userID/
 instructor_sets_assigned_to_user    /$courseID/instructor/users/$userID/sets/
 
 instructor_user_list2                /$courseID/instructor/users2/
 instructor_user_detail2              /$courseID/instructor/users2/$userID/ #not created yet
 instructor_sets_assigned_to_user2    /$courseID/instructor/users2/$userID/sets/ #not created yet

 
 instructor_set_list                 /$courseID/instructor/sets/
 instructor_set_detail               /$courseID/instructor/sets/$setID/
 instructor_users_assigned_to_set    /$courseID/instructor/sets/$setID/users/
 
 instructor_set_list2                 /$courseID/instructor/sets2/
 instructor_set_detail2               /$courseID/instructor/sets2/$setID/ #not created yet
 instructor_users_assigned_to_set2    /$courseID/instructor/sets2/$setID/users/ #not created yet
 
 instructor_add_users                /$courseID/instructor/add_users/
 instructor_set_assigner             /$courseID/instructor/assigner/
 instructor_file_transfer            /$courseID/instructor/files/
 instructor_file_manager             /$courseID/instructor/file_manager/
 instructor_set_maker                /$courseID/instructor/setmaker/
 instructor_set_maker2               /$courseID/instructor/setmaker2/
 instructor_set_maker3               /$courseID/instructor/setmaker3/
 instructor_get_target_set_problems  /$courseID/instructor/GetTargetSetProblems/
 instructor_get_library_set_problems /$courseID/instructor/GetLibrarySetProblems/
 instructor_config                   /$courseID/instructor/config/
 instructor_compare                  /$courseID/instructor/compare/
 
 instructor_problem_editor           /$courseID/instructor/pgProblemEditor/
 instructor_problem_editor_withset   /$courseID/instructor/pgProblemEditor/$setID/
 instructor_problem_editor_withset_withproblem
                                     /$courseID/instructor/pgProblemEditor/$setID/$problemID/
                                     
 instructor_problem_editor2           /$courseID/instructor/pgProblemEditor2/
 instructor_problem_editor2_withset   /$courseID/instructor/pgProblemEditor2/$setID/
 instructor_problem_editor2_withset_withproblem
                                     /$courseID/instructor/pgProblemEditor2/$setID/$problemID/
 
 instructor_scoring                  /$courseID/instructor/scoring/
 instructor_scoring_download         /$courseID/instructor/scoringDownload/
 instructor_mail_merge               /$courseID/instructor/send_mail/
 instructor_answer_log               /$courseID/instructor/show_answers/
 instructor_preflight               /$courseID/instructor/preflight/
 
 instructor_statistics               /$courseID/instructor/stats/
 instructor_set_statistics           /$courseID/instructor/stats/set/$setID/
 instructor_user_statistics          /$courseID/instructor/stats/student/$userID/
 
 instructor_progress                  /$courseID/instructor/StudentProgress/
 instructor_set_progress              /$courseID/instructor/StudentProgress/set/$setID/
 instructor_user_progress             /$courseID/instructor/StudentProgress/student/$userID/
 
 problem_list                        /$courseID/$setID/
 problem_detail                      /$courseID/$setID/$problemID/

 achievements                        /$courseID/achievements
 instructor_achievement_list         /$courseID//instructor/achievement_list
 instructor_achievement_editor       /$courseID/instructor/achievement_list/$achievementID/editor
 instructor_achievement_user_editor  /$courseID/instructor/achievement_list/$achievementID/users

=cut

################################################################################
# tree of path types
################################################################################

our %pathTypes = (
	root => {
		name    => 'WeBWorK',
		parent  => '',
		kids    => [ qw/course_admin  html2xml instructorXMLHandler set_list / ],
		match   => qr|^/|,
		capture => [ qw// ],
		produce => '/',
		display => 'WeBWorK::ContentGenerator::Home',
	},
	course_admin => {
		name    => 'Course Administration',
		parent  => 'root',
		kids    => [ qw/logout options instructor_tools/ ],
		match   => qr|^(admin)/|,
		capture => [ qw/courseID/ ],
		produce => 'admin/',
		display => 'WeBWorK::ContentGenerator::CourseAdmin',
	},
	
	################################################################################
	html2xml => {
		name    => 'html2xml',
		parent  => 'root', #    'set_list',
		kids    => [ qw// ],
		match   => qr|^html2xml/|,
		capture => [ qw// ],
		produce => 'html2xml/',
		display => 'WeBWorK::ContentGenerator::renderViaXMLRPC',
	},
	instructorXMLHandler => {
		name => 'instructorXMLHandler',
		parent => 'root',
		kids => [ qw// ],
		match   => qr|^instructorXMLHandler/|,
		capture => [ qw// ],
		produce => 'instructorXMLHandler/',
		display => 'WeBWorK::ContentGenerator::instructorXMLHandler',
	},
	set_list => {
		name    => '$courseID',
		parent  => 'root',
		kids    => [ qw/equation_display feedback gateway_quiz proctored_gateway_quiz grades hardcopy achievements
			logout options instructor_tools problem_list
		/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/courseID/ ],
		produce => '$courseID/',
		display => 'WeBWorK::ContentGenerator::ProblemSets',
	},
	
	################################################################################
	
	equation_display => {
		name    => 'Equation Display',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^equation/|,
		capture => [ qw// ],
		produce => 'equation/',
		display => 'WeBWorK::ContentGenerator::EquationDisplay',
	},
	feedback => {
		name    => 'Feedback',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^feedback/|,
		capture => [ qw// ],
		produce => 'feedback/',
		display => 'WeBWorK::ContentGenerator::Feedback',
	},
	gateway_quiz => {
		name    => 'Gateway Quiz $setID',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^quiz_mode/([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => 'quiz_mode/$setID/',
		display => 'WeBWorK::ContentGenerator::GatewayQuiz',
	},
	proctored_gateway_quiz => {
		name    => 'Proctored Gateway Quiz $setID',
		parent  => 'set_list',
		kids    => [ qw/proctored_gateway_proctor_login/ ],
		match   => qr|^proctored_quiz_mode/([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => 'proctored_quiz_mode/$setID/',
		display => 'WeBWorK::ContentGenerator::GatewayQuiz',
	},
	proctored_gateway_proctor_login => {
		name    => 'Proctored Gateway Quiz $setID Proctor Login',
		parent  => 'proctored_gateway_quiz',
		kids    => [ qw// ],
		match   => qr|^proctored_quiz_mode/([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => 'proctored_quiz_mode/$setID/proctor_login',
		display => 'WeBWorK::ContentGenerator::LoginProctor',
	},
	grades => {
		name    => 'Grades',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^grades/|,
		capture => [ qw// ],
		produce => 'grades/',
		display => 'WeBWorK::ContentGenerator::Grades',
	},
        achievements  => {
	        name    => 'Achievements',
                parent  => 'set_list',
                kids    => [ qw// ],
                match   => qr|^achievements/|,
                capture => [ qw// ],
                produce => 'achievements/',
                display => 'WeBWorK::ContentGenerator::Achievements',
        },
	hardcopy => {
		name    => 'Hardcopy Generator',
		parent  => 'set_list',
		kids    => [ qw/hardcopy_preselect_set/ ],
		match   => qr|^hardcopy/|,
		capture => [ qw// ],
		produce => 'hardcopy/',
		display => 'WeBWorK::ContentGenerator::Hardcopy',
	},
	hardcopy_preselect_set => {
		name    => 'Hardcopy Generator',
		parent  => 'hardcopy',
		kids    => [ qw// ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => 'WeBWorK::ContentGenerator::Hardcopy',
	},
	logout => {
		name    => 'Logout',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^logout/|,
		capture => [ qw// ],
		produce => 'logout/',
		display => 'WeBWorK::ContentGenerator::Logout',
	},
	options => {
		name    => 'Password/Email',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^options/|,
		capture => [ qw// ],
		produce => 'options/',
		display => 'WeBWorK::ContentGenerator::Options',
	},
	#test => {
	#	name    => 'Test',
	#	parent  => 'set_list',
	#	kids    => [ qw// ],
	#	match   => qr|^test/|,
	#	capture => [ qw// ],
	#	produce => 'test/',
	#	display => 'WeBWorK::ContentGenerator::Test',
	#},
	#render => {
	#	name    => 'Render',
	#	parent  => 'set_list',
	#	kids    => [ qw// ],
	#	match   => qr|^render/|,
	#	capture => [ qw// ],
	#	produce => 'render/',
	#	display => 'WeBWorK::ContentGenerator::ProblemRenderer',
	#},
	
	################################################################################
	
	instructor_tools => {
		name    => 'Instructor Tools',
		parent  => 'set_list',
		kids    => [ qw/instructor_user_list instructor_user_list2 instructor_set_list instructor_set_list2 
		    instructor_add_users instructor_achievement_list
			instructor_set_assigner instructor_file_manager
			instructor_problem_editor instructor_problem_editor2 
			instructor_set_maker instructor_set_maker2 instructor_set_maker3 
			instructor_get_target_set_problems instructor_get_library_set_problems instructor_compare
			instructor_config
			instructor_scoring instructor_scoring_download instructor_mail_merge
			instructor_answer_log instructor_preflight instructor_statistics
			instructor_progress			
		/ ],
		match   => qr|^instructor/|,
		capture => [ qw// ],
		produce => 'instructor/',
		display => 'WeBWorK::ContentGenerator::Instructor::Index',
	},
	
	################################################################################
	
	instructor_user_list => {
		name    => 'Classlist Editor',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_user_detail/ ],
		match   => qr|^users/|,
		capture => [ qw// ],
		produce => 'users/',
		display => 'WeBWorK::ContentGenerator::Instructor::UserList',
	},
	instructor_user_list2 => {
		name    => 'Classlist Editor2',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_user_detail/ ],
		match   => qr|^users2/|,
		capture => [ qw// ],
		produce => 'users2/',
		display => 'WeBWorK::ContentGenerator::Instructor::UserList2',
	},
	instructor_user_detail => {
		name    => 'Sets assigned to $userID',
		parent  => 'instructor_user_list',
		kids    => [ qw/instructor_sets_assigned_to_user/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/userID/ ],
		produce => '$userID/',
		display => 'WeBWorK::ContentGenerator::Instructor::UserDetail',
	},
	instructor_sets_assigned_to_user => {
		name    => 'Sets Assigned to User',
		parent  => 'instructor_user_detail',
		kids    => [ qw// ],
		match   => qr|^sets/|,
		capture => [ qw// ],
		produce => 'sets/',
		display => 'WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser',
	},
	
	################################################################################
	
	instructor_set_list => {
		name    => 'Hmwk Sets Editor',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_set_detail/ ],
		match   => qr|^sets/|,
		capture => [ qw// ],
		produce => 'sets/',
		display => 'WeBWorK::ContentGenerator::Instructor::ProblemSetList',
	},
	instructor_set_list2 => {
		name    => 'Hmwk Sets Editor2',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_set_detail/ ],
		match   => qr|^sets2/|,
		capture => [ qw// ],
		produce => 'sets2/',
		display => 'WeBWorK::ContentGenerator::Instructor::ProblemSetList2',
	},
	instructor_set_detail => {
		name    => 'Set Detail for set $setID',
		parent  => 'instructor_set_list',
		kids    => [ qw/instructor_users_assigned_to_set/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => 'WeBWorK::ContentGenerator::Instructor::ProblemSetDetail',
	},
	instructor_users_assigned_to_set => {
		name    => 'Users Assigned to Set $setID',
		parent  => 'instructor_set_detail',
		kids    => [ qw// ],
		match   => qr|^users/|,
		capture => [ qw// ],
		produce => 'users/',
		display => 'WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet',
	},
	
	################################################################################
	
	instructor_add_users => {
		name    => 'Add Users',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^add_users/|,
		capture => [ qw// ],
		produce => 'add_users/',
		display => 'WeBWorK::ContentGenerator::Instructor::AddUsers',
	},
	instructor_set_assigner => {
		name    => 'Set Assigner',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^assigner/|,
		capture => [ qw// ],
		produce => 'assigner/',
		display => 'WeBWorK::ContentGenerator::Instructor::Assigner',
	},
	instructor_config => {
		name    => 'Course Configuration',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^config/|,
		capture => [ qw// ],
		produce => 'config/',
		display => 'WeBWorK::ContentGenerator::Instructor::Config',
	},
	instructor_compare => {
		name    => 'File Compare',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^compare/|,
		capture => [ qw// ],
		#produce => 'comp/',
		produce => 'compare/',
		display => 'WeBWorK::ContentGenerator::Instructor::Compare',
	},
	instructor_set_maker => {
		name    => 'Library Browser',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^setmaker/|,
		capture => [ qw// ],
		produce => 'setmaker/',
		display => 'WeBWorK::ContentGenerator::Instructor::SetMaker',
	},
	instructor_set_maker2 => {
		name    => 'Library Browser 2',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^setmaker2/|,
		capture => [ qw// ],
		produce => 'setmaker2/',
		display => 'WeBWorK::ContentGenerator::Instructor::SetMaker2',
	},
		instructor_set_maker3 => {
		name    => 'Library Browser 3',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^setmaker3/|,
		capture => [ qw// ],
		produce => 'setmaker3/',
		display => 'WeBWorK::ContentGenerator::Instructor::SetMaker3',
	},
	instructor_get_target_set_problems => {
		name    => 'Get Target Set Problems',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^GetTargetSetProblems/|,
		capture => [ qw// ],
		produce => 'GetTargetSetProblems/',
		display => 'WeBWorK::ContentGenerator::Instructor::GetTargetSetProblems',
	},
	instructor_get_library_set_problems => {
		name    => 'Get Library Set Problems',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^GetLibrarySetProblems/|,
		capture => [ qw// ],
		produce => 'GetLibrarySetProblems/',
		display => 'WeBWorK::ContentGenerator::Instructor::GetLibrarySetProblems',
	},
	instructor_file_manager => {
		name    => 'File Manager',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^file_manager/|,
		capture => [ qw// ],
		produce => 'file_manager/',
		display => 'WeBWorK::ContentGenerator::Instructor::FileManager',
	},
	instructor_problem_editor => {
		name    => 'Problem Editor',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_problem_editor_withset/ ],
		match   => qr|^pgProblemEditor/|,
		capture => [ qw// ],
		produce => 'pgProblemEditor/',
		display => 'WeBWorK::ContentGenerator::Instructor::PGProblemEditor',
	},
	instructor_problem_editor2 => {
		name    => 'Problem Editor2',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_problem_editor2_withset/ ],
		match   => qr|^pgProblemEditor2/|,
		capture => [ qw// ],
		produce => 'pgProblemEditor2/',
		display => 'WeBWorK::ContentGenerator::Instructor::PGProblemEditor2',
	},
	instructor_problem_editor_withset => {
		name    => '$setID',
		parent  => 'instructor_problem_editor',
		kids    => [ qw/instructor_problem_editor_withset_withproblem/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => undef,
	},
	instructor_problem_editor2_withset => {
		name    => '$setID',
		parent  => 'instructor_problem_editor2',
		kids    => [ qw/instructor_problem_editor2_withset_withproblem/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => undef,
	},
	instructor_problem_editor_withset_withproblem => {
		name    => '$problemID',
		parent  => 'instructor_problem_editor_withset',
		kids    => [ qw// ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/problemID/ ],
		produce => '$problemID/',
		display => 'WeBWorK::ContentGenerator::Instructor::PGProblemEditor',
	},
	instructor_problem_editor2_withset_withproblem => {
		name    => '$problemID',
		parent  => 'instructor_problem_editor2_withset',
		kids    => [ qw// ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/problemID/ ],
		produce => '$problemID/',
		display => 'WeBWorK::ContentGenerator::Instructor::PGProblemEditor2',
	},
	instructor_scoring => {
		name    => 'Scoring Tools',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^scoring/|,
		capture => [ qw// ],
		produce => 'scoring/',
		display => 'WeBWorK::ContentGenerator::Instructor::Scoring',
	},
	instructor_scoring_download => {
		name    => 'Scoring Download',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^scoringDownload/|,
		capture => [ qw// ],
		produce => 'scoringDownload/',
		display => 'WeBWorK::ContentGenerator::Instructor::ScoringDownload',
	},
	instructor_mail_merge => {
		name    => 'Email',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^send_mail/|,
		capture => [ qw// ],
		produce => 'send_mail/',
		display => 'WeBWorK::ContentGenerator::Instructor::SendMail',
	},
	instructor_answer_log => {
		name    => 'Answer Log',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^show_answers/|,
		capture => [ qw// ],
		produce => 'show_answers/',
		display => 'WeBWorK::ContentGenerator::Instructor::ShowAnswers',
	},
	instructor_preflight => {
		name    => 'Preflight Log',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^preflight/|,
		capture => [ qw// ],
		produce => 'preflight/',
		display => 'WeBWorK::ContentGenerator::Instructor::Preflight',
	},
	
	################################################################################
	
	instructor_statistics => {
		name    => 'Statistics',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_set_statistics instructor_user_statistics/ ],
		match   => qr|^stats/|,
		capture => [ qw// ],
		produce => 'stats/',
		display => 'WeBWorK::ContentGenerator::Instructor::Stats',
	},
	instructor_set_statistics => {
		name    => 'Statistics',
		parent  => 'instructor_statistics',
		kids    => [ qw// ],
		match   => qr|^(set)/([^/]+)/|,
		capture => [ qw/statType setID/ ],
		produce => 'set/$setID/',
		display => 'WeBWorK::ContentGenerator::Instructor::Stats',
	},
	instructor_user_statistics => {
		name    => 'Statistics',
		parent  => 'instructor_statistics',
		kids    => [ qw// ],
		match   => qr|^(student)/([^/]+)/|,
		capture => [ qw/statType userID/ ],
		produce => 'student/$userID/',
		display => 'WeBWorK::ContentGenerator::Instructor::Stats',
	},

	################################################################################

        instructor_achievement_list => {
                name    =>  'Achievement Editor',
                parent  =>  'instructor_tools', 
                kids    =>  [ qw/instructor_achievement_editor instructor_achievement_user_editor/ ],
                match   =>  qr|^achievement_list/|,
                capture =>  [ qw// ],
                produce =>  'achievement_list/',
                display =>  'WeBWorK::ContentGenerator::Instructor::AchievementList',
        },

        instructor_achievement_editor => {
	        name    => 'Achievement Evaluator Editor',
                parent  => 'instructor_achievement_list', 
                kids => [ qw// ],
                match => qr|^([^/]+)/editor/|,
		capture => [ qw/achievementID/ ],
                produce => '$achievementID/editor/',
		display => 'WeBWorK::ContentGenerator::Instructor::AchievementEditor',
	},

        instructor_achievement_user_editor => {
	        name    => 'Achievement User Editor',
                parent  => 'instructor_achievement_list', 
                kids => [ qw// ],
		match   => qr|^([^/]+)/users/|,
		capture => [ qw/achievementID/ ],
		produce => '$achievementID/users/',
		display => 'WeBWorK::ContentGenerator::Instructor::AchievementUserEditor',
	},


	################################################################################
	
	instructor_progress => {
		name    => 'Student Progress',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_set_progress instructor_user_progress/ ],
		match   => qr|^progress/|,
		capture => [ qw// ],
		produce => 'progress/',
		display => 'WeBWorK::ContentGenerator::Instructor::StudentProgress',
	},
	instructor_set_progress => {
		name    => 'Student Progress',
		parent  => 'instructor_progress',
		kids    => [ qw// ],
		match   => qr|^(set)/([^/]+)/|,
		capture => [ qw/statType setID/ ],
		produce => 'set/$setID/',
		display => 'WeBWorK::ContentGenerator::Instructor::StudentProgress',
	},
	instructor_user_progress => {
		name    => 'Student Progress',
		parent  => 'instructor_progress',
		kids    => [ qw// ],
		match   => qr|^(student)/([^/]+)/|,
		capture => [ qw/statType userID/ ],
		produce => 'student/$userID/',
		display => 'WeBWorK::ContentGenerator::Instructor::StudentProgress',
	},
	
	################################################################################
	
	problem_list => {
		name    => '$setID',
		parent  => 'set_list',
		kids    => [ qw/problem_detail/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => 'WeBWorK::ContentGenerator::ProblemSet',
	},
	problem_detail => {
		name    => '$problemID',
		parent  => 'problem_list',
		kids    => [ qw// ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/problemID/ ],
		produce => '$problemID/',
		display => 'WeBWorK::ContentGenerator::Problem',
	},
	
);

=for comment

a handy template:

	id => {
		name    => '',
		parent  => '',
		kids    => [ qw// ],
		match   => qr|^/|,
		capture => [ qw// ],
		produce => '',
		display => '',
	},

=cut

################################################################################

=head1 CONSTRUCTORS

=over

=item new(%fields)

Creates a new WeBWorK::URLPath. %fields may contain the following:

 type => the internal path type associated with this 
 args => a reference to a hash associating path arguments with values

This constructor is used internally. Refer to newFromPath() and newFromModule()
for more useful constructors.

=cut

sub new {
	my ($invocant, %fields) = @_;
	my $class = ref $invocant || $invocant;
	my $self = {
		type => undef,
		r    => undef,             # will point to the parent request object (for access to the $ce)
		args => {},
		%fields,
	};
	return bless $self, $class;
}

=item newFromPath($path)

Creates a new WeBWorK::URLPath by parsing the path given in $path. It the path
is invalid, an exception is thrown.

=cut

sub newFromPath {
	my ($invocant,  $path, $r) = @_;
	
	my ($type, %args) = getPathType($path);
	croak "no type matches path $path" unless $type;
	croak "URLPath requires a request object parent as second element" unless (ref($r) =~/WeBWorK::Request/);
	
	return $invocant->new(
		type => $type,
		r    => $r,             # will point to the parent request object (for access to the $ce)
		args => \%args,
	);
}

=item newFromModule($module,  $r, %args)

Creates a new WeBWorK::URLPath by finding a path type which matches the module
and path arguments given. If no type matches, an exception is thrown.

=cut

sub newFromModule {
	my ($invocant, $module, $r, %args) = @_;
	
	my $type = getModuleType($module, keys %args);
	croak "URLPath requires a request object parent as second element" unless (ref($r) =~/WeBWorK::Request/);
	croak "no type matches module $module with args", map { " $_=>$args{$_}" } keys %args unless $type;
	
	return $invocant->new(
		type => $type,
		r    => $r,
		args => \%args
	);
}

=back

=cut

################################################################################

=head1 METHODS

=head2 Methods that return information from the object itself

=over

=item type()

Returns the path type of the WeBWorK::URLPath.

=cut

sub type {
	my ($self) = @_;
	my $type = $self->{type};
	
	return $type;
}

=item args()

Returns a hash of arguments derived from the WeBWorK::URLPath.

=cut

sub args {
	my ($self) = @_;
	my %args = %{ $self->{args} };
	
	return %args;
}

=item arg($name)

Returns the named argument, as derived from the WeBWorK::URLPath.

=cut

sub arg {
	my ($self, $name) = @_;
	my %args = %{ $self->{args} };
	
	return $args{$name};
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Methods that return information from path node associated with the object

=over

=item name()

Returns the human-readable name of this WeBWorK::URLPath.

=cut

sub name {
	my ($self) = @_;
	my $type = $self->{type};
	my %args = $self->args;
	
	my $name = $pathTypes{$type}->{name};
	$name = $self->{r}->maketext($name);   # translate the display name
	$name = interpolate($name, %args);
	
	return $name;
}

=item module()

Returns the name of the module that will handle this WeBWorK::URLPath.

=cut

sub module {
	my ($self) = @_;
	my $type = $self->{type};
	
	return $pathTypes{$type}->{display};
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Methods that search the virtual heirarchy

=over

=item parent()

Returns a new WeBWorK::URLPath representing the parent of the current URLPath.
Returns an undefined value if the URLPath has no parent.

=cut

sub parent {
	my ($self) = @_;
	my $type = $self->{type};
	
	my $newType = $pathTypes{$self->{type}}->{parent};
	return undef unless $newType;
	
	# remove any arguments added by the current node (and therefore not needed by the parent)
	my @currArgs = @{ $pathTypes{$type}->{capture} };
	my %newArgs = %{ $self->{args} };
	delete @newArgs{@currArgs} if @currArgs;
	# use the same request object "parent" for parent URLPath as for the child
	return $self->new(type => $newType, r => $self->{r}, args => \%newArgs);
}

=item child($module, %newArgs)

Returns a new WeBWorK::URLPath representing the child of the current URLPath
whose module is C<$module>. If no child matches, an undefined value is returned.
Pass additional arguments needed by the child in C<%newArgs>.

=cut

sub child {
	my ($self, $module, %newArgs) = @_;
	my $type = $self->{type};
	
	my @kids = @{ $pathTypes{$type}->{kids} };
	my $newType;
	foreach my $kid (@kids) {
		if ($pathTypes{$kid}->{module} eq $module) {
			$newType = $kid;
			last;
		}
	}
	
	if ($newType) {
		return $self->new(type => $newType, args => \%newArgs);
	} else {
		return undef;
	}
}

=item path()

Reconstructs the path string from a WeBWorK::URLPath.

=cut

sub path {
	my ($self) = @_;
	my $type = $self->type;
	my %args = %{ $self->{args} };
	
	my $path = buildPathFromType($type);
	$path = interpolate($path, %args);
	
	return $path;
}

=back

=cut



################################################################################

=head1 UTILITY FUNCTIONS

=over

=item all_modules()

Return a list of the display modules associated with all possible path types.

=cut

sub all_modules {
	my @modules = grep { defined } map { $pathTypes{$_}{display} } keys %pathTypes;
	my %modules; @modules{@modules} = (); # remove duplicates
	return keys %modules;
}

=item interpolate($string, %symbols)

Replaces simple scalars (\$\w+) in $string with values in %symbols. If a scalar
does not exist in %symbols, it is left alone.

=cut

sub interpolate {
	my ($string, %symbols) = @_;
	
	$string =~ s/\$(\w+)/exists $symbols{$1} ? $symbols{$1} : "\$$1"/eg;
	
	return $string;
}

=back

=cut

# ------------------------------------------------------------------------------

=over

=item getPathType($path)

Parse the string $path, determining the path type. Returns ($type, %args), where
$type is the type of the path and %args contains any extracted path arguments.
If conversion fails, a false value is returned.

=cut

sub getPathType($) {
	my ($path) = @_;
	
	my %args;
	my $context = visitPathTypeNode("root", $path, \%args, 0);
	
	return $context, %args;
}

=item getModuleType($module, @args)

Returns the path type matching the given module and argument names, or a false
value if no type matches.

=cut

sub getModuleType {
	my ($module, @args) = @_;
	@args = sort @args;
	my %args;
	@args{@args} = ();
	
	NODE: foreach my $nodeID (keys %pathTypes) {
		my $node = $pathTypes{$nodeID};
		
		# module name matches?
		next NODE unless defined $node->{display} and $node->{display} eq $module;
		
		# collect all captures from here to root
		my @captures;
		my $tmpNodeID = $nodeID;
		while ($tmpNodeID) {
			my $tmpNode = $pathTypes{$tmpNodeID};
			push @captures, @{ $tmpNode->{capture} };
			$tmpNodeID = $tmpNode->{parent};
		}
		
		# same number of captures?
		next NODE unless @captures == @args;
		
		# same captures?
		@captures = sort @captures;
		for (my $i = 0; $i < @args; $i++) {
			next NODE unless $args[$i] eq $captures[$i];
		}
		
		# if we got here, this node matches
		return $nodeID;
	}
	
	return 0; # no node matches
}

=item buildPathFromType($type)

Returns a string path for the given path type. Since arguments are not supplied,
the string may contain scalar variables ripe for interpolation.

=cut

sub buildPathFromType($) {
	my ($type) = @_;
	
	my $path = "";
	
	while ($type) {
		$path = $pathTypes{$type}->{produce} . $path;
		$type = $pathTypes{$type}->{parent};
	};
	
	return $path;
}

=item visitPathTypeNode($nodeID, $path, $argsRef, $indent)

Internal search function. See getPathType().

Returns the nodeID of the node that consumed the final characters in $path, or
the following failure conditions:

Returns 0 if $nodeID doesn't match $path.

Returns -1 if $nodeID matched $path, but no children of $nodeID consumed the
remaining path. In this case, the stack is unwound immediately.

=cut

sub visitPathTypeNode($$$$);

sub visitPathTypeNode($$$$) {
	my ($nodeID, $path, $argsRef, $indent) = @_;
	debug("visitPathTypeNode", $indent, "visiting node $nodeID with path $path");
	
	unless (exists $pathTypes{$nodeID}) {
		debug("visitPathTypeNode", $indent, "node $nodeID doesn't exist in node list: failed");
		die "node $nodeID doesn't exist in node list: failed";
	}
	
	my %node = %{ $pathTypes{$nodeID} };
	my $match = $node{match};
	my @capture_names = @{ $node{capture} };
	
	# attempt to match $path against $match.
	debug("visitPathTypeNode", $indent, "trying to match $match: ");
	if ($path =~ s/($match)//) {
		# it matches! store captured strings in $argsRef and remove the matched
		# characters from $path. waste a lot of lines on sanity checking... ;)
		debug("", 0, "success!");
		my @capture_values = $1 =~ m/$match/;
		if (@capture_names) {
			my $nexpected = @capture_names;
			my $ncaptured = @capture_values;
			my $max = $nexpected > $ncaptured ? $nexpected : $ncaptured;
			warn "captured $ncaptured arguments, expected $nexpected." unless $ncaptured == $nexpected;
			for (my $i = 0; $i < $max; $i++) {
				my $name = $capture_names[$i];
				my $value = $capture_values[$i];
				if ($i > $nexpected) {
					warn "captured an unexpected argument: $value -- ignoring it.";
					next;
				}
				if ($i > $ncaptured) {
					warn "expected an uncaptured argument named: $name -- ignoring it.";
					next;
				}
				if (exists $argsRef->{$name}) {
					my $old = $argsRef->{$name};
					warn "encountered argument $name again, old value: $old new value: $value -- replacing.";
				}
				debug("visitPathTypeNode", $indent, "setting argument $name => $value.");
				$argsRef->{$name} = $value;
			}
		}
	} else {
		# it doesn't match. bail out now with return value 0
		debug("", 0, "failed.");
		return 0;
	}
	
	##### if we're here we matched #####
	
	# if there's no more path left, then this node is the one! return $nodeID
	if ($path eq "") {
		debug("visitPathTypeNode", $indent, "no path left, type is $nodeID");
		return $nodeID;
	}
	
	# otherwise, we have to send the remaining path to the node's children
	debug("visitPathTypeNode", $indent, "but path remains: $path");
	my @kids = @{ $node{kids} };
	if (@kids) {
		foreach my $kid (@kids) {
			debug("visitPathTypeNode", $indent, "trying child $kid:");
			my $result = visitPathTypeNode($kid, $path, $argsRef, $indent+1);
			# we return in two situations:
			# if $result is -1, then the kid matched but couldn't consume the rest of the path
			# if $result is the ID of a node, then the kid matched and consumed the rest of the path
			# these are all true values (assuming that "0" isn't a valid node ID), so we say:
			return $result if $result;
		}
		debug("visitPathTypeNode", $indent, "no children claimed the remaining path: failed.");
	} else {
		debug("visitPathTypeNode", $indent, "no children to claim the remaining path: failed.");
	}
	
	# in both of the above cases, we matched but couldn't provide children that
	# would consume the rest of the path. so we return -1, causing the whole
	# stack to unwind. WHEEEEEEE!
	return -1;
}

=back

=cut

1;
